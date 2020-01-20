require "gmail"


  USERNAME = "shogo14kinjo@gmail.com"
  PASSWORD = "zmwetsgkkaogqgoa"
  gmail = Gmail.new(USERNAME, PASSWORD)
  
  message =
    gmail.generate_message do
      to "shogo14kinjo@gmail.com"
      subject "題名"
      html_part do
        content_type "text/html; charset=UTF-8"
        body "<h1>エラーが発生しました。</h1><p>test</p>" + "<p>画面を確認して正常にリトライされているかを確認してください。</p>"
      end
    end
  
  gmail.deliver(message)
  gmail.logout