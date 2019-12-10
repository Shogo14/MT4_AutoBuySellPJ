require 'yaml'
require 'fileutils'
require 'time'
# require 'io/console'

#処理起動の最初と、処理停止の直前に実行
def signal_file_backup(work_folder)
    puts "シグナルファイルのバックアップ開始"
    $logger.info("シグナルファイルのバックアップ開始")
    current_folder = Dir.pwd
    Dir.chdir work_folder
    unless File.exist?("old")
        Dir.mkdir("old")
    end
    data_files = Dir.glob('*.*')
    today = Time.now.strftime "%Y%m%d"
    data_files.each do |data_file|
        unless data_file.include?('_'+ today)
            if data_file.include?('HistorySignal_')
                $logger.info(data_file + "をバックアップします")
                FileUtils.mv(data_file,"old/"+data_file)
            elsif data_file.include?('SignalData_')
                $logger.info(data_file + "を削除します")
                FileUtils.rm_f(data_file)
            end
        end
    end
    Dir.chdir current_folder
    puts "シグナルファイルのバックアップ終了"
    $logger.info("シグナルファイルのバックアップ終了")
end

def signal_read(signal_folder_path,pre_update_time,today)
    #カレントディレクトリを取得しておく。
    base_dir = Dir.pwd
    Dir.chdir signal_folder_path
    signal_files = Dir.glob('*.*')

    arrSignals = ""
    #Historyファイル名を定義
    history_filename = "HistorySignal_" + today + ".txt"
    signal_files.each do |signal_file|
        if signal_file.include?("SignalData_" + today)
            $logger.info("【#{signal_file}】のファイル更新日時を取得")
            #今日の日付を含むファイルがある場合、ファイル更新日時を取得
            last_update_datetime = File.mtime(signal_file).iso8601(3)
            f = ""
            
            begin
                retries ||= 0
                f = File.open(signal_file,'r') 
            rescue
                retry if (retries += 1) < 10
            end
            
            signal = f.readlines.last 
            $logger.info("【#{signal_file}】を削除します。")
            #Fileオブジェクトをclose
            f.close unless f.nil? or f.closed?
            #signal_file を削除
            File.delete(f) if File.exist? signal_file  
            #History_fileにシグナルを追記
            history_file = File.open(history_filename,"w")
            history_file.puts(signal)
            
            if last_update_datetime > pre_update_time
                $logger.info("【#{signal_file}】の最新更新日時が前回の更新日時を超えたためシグナルを取得")
                $logger.info("【#{signal_file}】の最新更新日時：#{last_update_datetime.to_s}")
                $logger.info("シグナルファイルの前回更新日時:#{pre_update_time.to_s}")
                #ファイルの最終更新日時が、更新されている場合
                arrSignals = signal.split(",")
                pre_update_time = last_update_datetime
            end
        end
    end
    #ディレクトリを戻す
    Dir.chdir base_dir
    return arrSignals,pre_update_time
end

