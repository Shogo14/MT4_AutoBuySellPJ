require 'selenium-webdriver'
require 'time'
require 'date'
require 'yaml'
require 'logger'
require "gmail"
require './signal_init'


#前回更新日時
pre_update_time    = Time.now
print(pre_update_time)
sabun = 45 - pre_update_time.sec
print("     ")
if(sabun >= 0)
    print(sabun)
else
    print(60 + sabun )
end
# print(45 - pre_update_time.sec)
#最終決済時間
# sleep(10)
# last_settlement_time = Time.now + 10
# #最終操作時間
# print((last_settlement_time - pre_update_time).to_i)