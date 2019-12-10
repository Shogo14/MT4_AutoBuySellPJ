require 'selenium-webdriver'
require 'time'
require 'date'
require 'yaml'
require 'logger'
require './signal_init'

def main
	log_filename = log_init
	$logger = Logger.new('../log/' + log_filename)
	$logger.info("自動売買プログラムを開始") 

	config             = YAML.load_file("config/config.yml")
	production_flg     = config["init_param"]["production"]
	currency_pare      = config["init_param"]["currency_pare"]
	buy_amount         = config["init_param"]["amount"]

	user_id            = config["high_low_aus"]["user_id"]
	password           = config["high_low_aus"]["password"]
	re_init_time       = config["high_low_aus"]["re_init_min_time"]
	re_buy_sec_time    = config["high_low_aus"]["re_buy_sec_time"]

	signal_folder_path = config["signal"]["folder_path"]

	start_time         = Time.parse(config["auto_trading_time"]["start_time"])
	end_time           = Time.parse(config["auto_trading_time"]["end_time"])

	#前回更新日時
	pre_update_time    = Time.now.iso8601(3)
	#最終決済時間
	last_settlement_time = Time.now.iso8601(3)
	#最終操作時間
	last_init_time = Time.now

	#終了時間より開始時間の方が大きい場合、終了時間に24時間加算する
	end_time = end_time + (60 * 60 * 24) if start_time > end_time
	$logger.info("設定ファイル　取引開始：" + start_time.to_s + "　取引終了：" + end_time.to_s)
	#現在時刻が終了時刻を過ぎている場合、exit
	if Time.now > end_time
		$logger.warn("Configファイルにて指定した終了時刻を過ぎています。処理を終了します。")
		exit 
	end

	signal_file_backup(signal_folder_path)
	
	$driver = Selenium::WebDriver.for :chrome # ブラウザ起動
	$wait = Selenium::WebDriver::Wait.new(timeout: 200)
	
	$logger.info("スクレイピング開始") 
	if production_flg == "on"
		puts "=====本番環境====="
		$logger.info("=====本番環境=====")
		login(user_id: user_id,password: password,url: "https://trade.highlow.com/")
	else
		puts "=====デモ環境====="
		$logger.info("=====デモ環境=====")
		login(user_id: nil,password: nil,url: "https://demotrade.highlow.com/")
	end

	high_low_aus_init(currency_pare)
	sleep(1)
	re_init_flg = true

	while Time.now <= end_time do
		re_init_flg = true
		#現在時刻が終了時刻を超えていない場合
		# trading_flg = trading?
		if trading_now?
			$logger.info("取引中のため待機") 
			#取引中は最終決済時間を初期化
			last_settlement_time = nil
			sleep(10)
		else
			#最後に決済を終えた時間
			last_settlement_time = Time.now.iso8601(3) if last_settlement_time.nil?
			#本日の日付をyyyyMMddで取得
			today = Time.now.strftime "%Y%m%d"
			#取引中ポジションがない場合
			arrSignals,pre_update_time = signal_read(signal_folder_path,pre_update_time,today)
			if arrSignals != ""
				#シグナルが存在する場合
				signal = arrSignals.first.downcase
				mt4_signal_datetime = (Time.parse(arrSignals.last) + 10).iso8601(3)
				$logger.info("シグナル:  " + signal.to_s) 
				$logger.info("MT4のシグナル出力時間が最終決済時間を超えた場合購入処理をする。") 
				$logger.info("MT4のシグナル出力時間: " + mt4_signal_datetime.to_s)
				$logger.info("最終決済時間：" + last_settlement_time.to_s) 
				if mt4_signal_datetime >= last_settlement_time
					result = ""
					until result.include?("成功") || mt4_signal_datetime <= (Time.now - re_buy_sec_time.to_i).iso8601(3) do
						result = buy(buy_amount,signal,mt4_signal_datetime,re_buy_sec_time)
					end
					
					last_init_time = Time.now
					re_init_flg = false
				end
			end
		end

		if re_init_flg && last_init_time + (60 * re_init_time.to_i) < Time.now
			tarbo_usdjpy_init
			last_init_time = Time.now
		end
	end
	$logger.info("設定した取引終了時刻を過ぎたので、自動売買を終了します。")

	sleep(10)
	$driver.quit
rescue SystemExit
	$logger.info("System Exit...")

end

def login(user_id: nil,password: nil,url: "")
	puts "ログイン処理開始"
	$logger.info("ログイン処理開始")
	
	$logger.info("指定URLにナビゲート")
	$driver.navigate.to url

	$logger.info("画面の最大化")
	$driver.manage.window.maximize

	$logger.info("タイムアウトを200秒に設定")
	$driver.manage.timeouts.implicit_wait = 200
	
	if user_id && password
		#本番環境
		puts "本番環境でのログイン処理"
		$logger.info("本番環境でのログイン処理")
		$logger.info("サイトにアクセス開始、ログイン画面へ遷移")
		$wait.until { $driver.find_element(:xpath, "//*[@id=\"header\"]/div/div/div/div/div/span/span/a[2]/i").displayed? }
		$driver.find_element(:xpath, "//*[@id=\"header\"]/div/div/div/div/div/span/span/a[2]/i").click

		$logger.info("usernameを入力")
		$wait.until { $driver.find_element(:id,"login-username").displayed? }
		$driver.find_element(:id,"login-username").send_keys user_id

		$logger.info("passwordを入力")
		$wait.until { $driver.find_element(:id,"login-password").displayed? }
		$driver.find_element(:id,"login-password").send_keys password

		$logger.info("ログインをクリック")
		$wait.until { $driver.find_element(:xpath, "//*[@id=\"signin-popup\"]/div[1]/div/div[2]/div[1]/form/div/div[6]/button/span[2]").displayed? }
		$driver.find_element(:xpath, "//*[@id=\"signin-popup\"]/div[1]/div/div[2]/div[1]/form/div/div[6]/button/span[2]").click

		$logger.info("ログイン完了まで待つ")
		$wait.until {$driver.find_element(:class,'logged-in')}
		$logger.info("ログイン完了")
	else
		#デモ環境
		puts "デモ環境でのログイン処理"
		$logger.info("デモ環境でのログイン処理")
		$logger.info("クイックデモを選択")
		$wait.until { $driver.find_element(:xpath,"//*[@id=\"header\"]/div/div/div/div/div/span/span/a[1]/i").displayed? }
		$driver.find_element(:xpath,"//*[@id=\"header\"]/div/div/div/div/div/span/span/a[1]/i").click
		
		$logger.info("取引を始めるを選択")
		$wait.until { $driver.find_element(:xpath,"//*[@id=\"account-balance\"]/div[2]/div/div[1]/a").displayed? }
		$driver.find_element(:xpath,"//*[@id=\"account-balance\"]/div[2]/div/div[1]/a").click
	end
	puts "ログイン処理終了"
	$logger.info("ログイン処理終了")
end

def high_low_aus_init(currency_pare)
	puts "HighLowオーストラリアの購入前準備開始"
	$logger.info("HighLowオーストラリアの購入前準備開始")
	
	$logger.info("Tarboを選択")
	sleep(1)
	$wait.until { $driver.find_element(:xpath,"//*[@id=\"ChangingStrikeOOD\"]").enabled? }
	$wait.until { $driver.find_element(:xpath,"//*[@id=\"ChangingStrikeOOD\"]").displayed? }
	$driver.find_element(:xpath,"//*[@id=\"ChangingStrikeOOD\"]").click

	sleep(1)

	if $driver.find_element(:xpath,"//*[@id=\"tradingClosed\"]").displayed?
		$logger.fatal("取引時間外です。処理を終了します。")
		exit
	end

	$logger.info("5分を選択")
	$wait.until { $driver.find_element(:xpath,"//*[@id=\"assetsCategoryFilterZoneRegion\"]/div/div[5]/span").displayed? }
	$driver.find_element(:xpath,"//*[@id=\"assetsCategoryFilterZoneRegion\"]/div/div[5]/span").click

	$logger.info("全ての資産タブを選択")
	$wait.until { $driver.find_element(:class,"asset-filter--opener").displayed? }
	$driver.find_element(:class,"asset-filter--opener").click 

	$logger.info("USD/JPYを入力")
	$wait.until { $driver.find_element(:xpath,"//*[@id=\"searchBox\"]").displayed? }
	$driver.find_element(:xpath,"//*[@id=\"searchBox\"]").send_keys(currency_pare)

	$logger.info("USD/JPYを選択")	
	$wait.until { $driver.find_element(:xpath,"//*[@id=\"assetsFilteredList\"]").displayed? }
	$driver.find_element(:xpath,"//*[@id=\"assetsFilteredList\"]").click

	puts "HighLowオーストラリアの購入前準備終了"
	$logger.info("HighLowオーストラリアの購入前準備終了")	
end

def buy(amount,updown,mt4_signal_datetime,re_buy_sec_time)

	puts "購入処理開始"
	$logger.info("購入処理開始")
	$wait.until { $driver.find_element(:xpath,"//*[@id=\"amount\"]").displayed? }
	amount_field = $driver.find_element(:xpath,"//*[@id=\"amount\"]")
	amount_field.clear
	amount_field.send_keys(amount)
	result = ""

	$logger.info("High or Low を選択")
	case updown
		when 'high-entry' then
			$logger.info("Highボタンをクリック")
			$wait.until { $driver.find_element(:xpath,"//*[@id=\"up_button\"]").displayed? }
			$driver.switch_to.window( $driver.window_handles.last )
			$driver.find_element(:xpath,"//*[@id=\"up_button\"]").click
		when 'low-entry' then
			$logger.info("Lowボタンをクリック")
			$wait.until { $driver.find_element(:xpath,"//*[@id=\"down_button\"]").displayed? }
			$driver.switch_to.window( $driver.window_handles.last )
			$driver.find_element(:xpath,"//*[@id=\"down_button\"]").click
		else
			$logger.fatal("シグナルの値が不正です。：" + updown)
			exit
	end

	$logger.info("購入ボタンをクリック")
	$wait.until { $driver.find_element(:xpath,"//*[@id=\"invest_now_button\"]").displayed? }
	$driver.find_element(:xpath,"//*[@id=\"invest_now_button\"]").click

	wait = Selenium::WebDriver::Wait.new(timeout: 2)
	$logger.info("購入成功を確認")
	wait.until { $driver.find_element(:xpath,"//*[@id=\"notification_text\"]").displayed? }
	sleep(2)
	while result == "" || result.include?("処理中") do
		result = $driver.find_element(:xpath,"//*[@id=\"notification_text\"]").text
		$logger.info("購入結果：" + result)
		if mt4_signal_datetime <= (Time.now - re_buy_sec_time.to_i).iso8601(3)
			time_limit = (Time.now - re_buy_sec_time.to_i).iso8601(3) - mt4_signal_datetime
			$logger.info("再購入可能時間　残り：" + time_limit.to_s)
			break
		end
	end
	puts "購入処理終了"
	$logger.info("購入処理終了")
	return result
end

def trading_now?
	trading_flg = false
	unless $driver.find_element(:xpath,"//*[@id=\"trade_actions_container\"]/div[2]/div[1]").displayed?
		tradings = $driver.find_elements(:css,"#tradeActionsTableBody tr.trade-details-tbl")
		if tradings.count > 0
			tradings.each do |trading|
				if trading.text.include?("取引中")
					trading_flg = true
					break
				end
			end
		end
	end
	trading_flg
end

def log_init
	puts "ログファイルの準備開始"

    current_folder = Dir.pwd
	Dir.chdir "../log"
	log_files = Dir.glob('*.*')

	one_month_ago = Date.today - 30

	log_files.each do |log_file|
		f_update_date = File.mtime(log_file).to_date
		if one_month_ago > f_update_date
			puts "【#{log_file}】を削除します。"
			File.delete(log_file) if File.exist? log_file
		end
	end

	now_time = Time.now.strftime "%Y%m%d%H%M%S"
	log_filename = "AutoBuySell_Log_" + now_time + ".log"
	f = File.open(log_filename,'w')
	f.close unless f.nil? or f.closed?
	Dir.chdir current_folder

	puts "ログファイルの準備終了"

	return log_filename
end
  
# log_init
main
