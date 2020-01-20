@echo off
rem tempフォルダがなければ作成
if not exist %temp%\ (
 mkdir %temp%
)
rem 実行
cd C:\MT4_Ruby_Program\AutoBuySellPJ
ruby function.rb

pause