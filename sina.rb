require 'mechanize'
require 'digest/sha1'

def login(agent, username, password)
  html = agent.get('http://weibo.com').body
  servertime = html[/\$severtime\s+:\s*"(\d+)"/ ,1]
  nonce = 1.upto(6).map{65.+(rand(25)).chr}.join
  pwencode = 'wsse'
  pword = Digest::SHA1.hexdigest(Digest::SHA1.hexdigest(Digest::SHA1.hexdigest(password)) + servertime + nonce)
  req = agent.post('http://login.sina.com.cn/sso/login.php?client=ssologin.js(v1.3.14)',
        'entry' => 'miniblog',
        'gateway' => '1',
        'savestate' => '7',
        'useticket' => '1',
        'ssosimplelogin' => '1',
        'username' => username,
        'service' => 'miniblog',
        'servertime' => servertime,
        'nonce' => nonce,
        'pwencode' => pwencode,
        'password' => pword,
        'encoding' => 'utf-8',
        'url' => 'http://weibo.com/ajaxlogin.php?framelogin=1&callback=parent.sinaSSOController.feedBackUrlCallBack',
        'returntype' => 'META'
        )

  location = req.body[/location.replace\("(.*)"\)/, 1]
  req = agent.get(location)
  req = agent.get('http://www.weibo.com')
  puts req.body
end

