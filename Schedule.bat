@echo off
rem temp�t�H���_���Ȃ���΍쐬
if not exist %temp%\ (
 mkdir %temp%
)
rem ���s
cd C:\MT4_Ruby_Program\AutoBuySellPJ
ruby function.rb

pause