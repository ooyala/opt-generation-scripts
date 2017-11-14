#!/usr/bin/env ruby

# This is a tool used to generate embed token signature given the provider api_key, secret, pcode, list of embed codes, and expiration
require "base64"
require "digest/sha2"
require "digest/md5"
require "cgi"
require "open-uri"
require "optparse"
require "net/http"

USAGE = <<ENDUSAGE
Usage: 
   OoyalaPlayerTokenGenerator [-h] [-e embed_code] [-a api_key] [-s api_secret] [-h hashing_method] [-i expires] [-q account_id] [-t override_syndication_group] [-d device] [-w domain] [-f supported_formats] [-p postal_code]
ENDUSAGE
HELP = <<ENDHELP
   -h, --help                           Show this help.
   -e, --embed_code                     (Required) You supply one or more embed codes that represent 
                                        the players that will be embedded on the page. You can use up 
                                        to 50 embed codes. You may specify a value of all if you would 
                                        like to create the playback token to be used with multiple assets 
                                        (over 50 embed codes). This is useful when using the rights 
                                        locker with applications that want to create the playback token 
                                        for multiple assets.
   -a, --api_key                        (Required) If API access is enabled for your account,
                                        Ooyala provides you with an API Key (see the Developers
                                        tab in the Backlot UI).
   -s, --api_secret                     (Required) Your 40 character secret key (see the Developers
                                        tab in the Backlot UI); it is unique for each user and should
                                        always be kept secure and private.
   -i, --expires                        (Optional) The POSIX time at which point the token expires.
                                        Use a short expiration time on the URL snippet so that the snippet 
                                        cannot be replicated across other domains (more precisely, it can 
                                        be embedded, but will become nonfunctional). If no time is set,
                                        current time + 10 minutes will be used.
   -m, --hashing_method                 (Optional) MD5 or SHA256.
   -q, --account_id                     (Optional) Your account or user identifier. While not 
                                        always necessary in the Ooyala Player Token, the 
                                        account_id is required for working with entitlements 
                                        (such as eCommerce), concurrent stream limits, 
                                        cross-device resume, or device registration. 
                                        Use this parameter in conjunction with Rights Locker 
                                        and Device Registration API.
   -t, --override_syndication_group     (Optional) Disables all syndication controls set in Backlot 
                                        (geo restrictions, flight times, domain controls, etc.). 
                                        The usage of this is only recommended for testing purposes.
   -d, --device                         (Optional) This is used to determine which stream formats are
                                        compatible with the current device.
   -w, --domain                         (Optional) The domain where the player is being loaded.
   -f, --supported_formats              (Optional) This is only required if you intend to retrieve a
                                        specific set of supported formats
   -p, --postal_code                    (Optional) If you implement postal code DMA, this is the parameter
                                        you use to validate against the assets syndication rules

ENDHELP

def generate_signature(api_secret, pcode, embed_code, hashing_method, params)
  string_to_sign = "#{api_secret}GET/sas/embed_token/#{pcode}/#{embed_code}"
  params.sort.map do |key,value|
    if value != ""
      string_to_sign = string_to_sign + "#{key}=#{value}"
    end
  end
  if hashing_method == "MD5"
    return Base64::encode64(Digest::MD5.digest(string_to_sign))[0..42]
  else
    puts "\nString to Sign: \n" + string_to_sign
    digest = Digest::SHA256.digest(string_to_sign)
    signature = Base64::encode64(digest).chomp.gsub(/=+$/, '')
    signature = CGI.escape(signature)
    puts "\nSignature: \n" + signature
    return signature
  end
end

def generate_token(server, pcode, embed_code, params)
  token = "http://#{server}/embed_token/#{pcode}/#{embed_code}?"
  params.sort.map do |key,value|
    if value != ""
      token = token + "#{key}=#{value}&"
    end
  end
  token.chop!
  return token
end

options = {}	
ARGV.options do |opts|
    opts.on("-e", "--embed_code embed_code", String) { |embed_code| options[:embed_code] = embed_code } 
    opts.on("-a", "--api_key api_key", String) { |api_key| options[:api_key] = api_key }
    opts.on("-s", "--api_secret api_secret", String) { |api_secret| options[:api_secret] = api_secret }
    opts.on("-m", "--hashing_method hashing_method", String) { |hashing_method| options[:hashing_method] = hashing_method }
    opts.on("-i", "--expires expires", String) { |expires| options[:expires] = expires }
    opts.on("-q", "--account_id account_id", String) { |account_id| options[:account_id] = account_id }
    opts.on("-t", "--override_syndication_group override_syndication_group", String) { |override_syndication_group| options[:override_syndication_group] = override_syndication_group }
    opts.on("-d", "--device device", String) { |device| options[:device] = device }
    opts.on("-w", "--domain domain", String) { |domain| options[:domain] = domain }
    opts.on("-f", "--supported_formats supported_formats", String) { |supported_formats| options[:supported_formats] = supported_formats }
    opts.on("-p", "--postal_code postal_code", String) { |postal_code| options[:postal_code] = postal_code }
    opts.on("-h", "--help") { options[:help] = true }
    opts.parse!
end

# Use this section if you need to hardcode values (not recommended)
params = Hash.new
params["api_key"] = options[:api_key] || ""
params["expires"] = options[:expires] || "#{Time.now.to_i + 10*60}"
params["account_id"] = options[:account_id] || ""
params["override_syndication_group"] = options[:override_syndication_group] || ""
params["postal_code"] = options[:postal_code] || ""
pcode = params["api_key"][0...-6]
api_secret = options[:api_secret] || ""
embed_code = options[:embed_code] || ""
hashing_method = options[:hashing_method] || "SHA256"
server = "player.ooyala.com/sas"
domain = options[:domain] || "www.ooyala.com"
device = options[:device] || "GENERIC" # IPHONE, IPAD, APPLE_TV, ANDROID_SDK, ANDROID_3PLUS_SDK, ANDROID_HLS_SDK, HTML5, GENERIC_FLASH, GENERIC
supported_formats = options[:supported_formats] || "" # hds, rtmp, m3u8, mp4, akamai_hd, wv_hls, wv_mp4, wv_wvm, faxs_hls, smooth

# Required parameters
if options[:help] || embed_code == "" || api_secret == "" || params["api_key"] == ""
  puts USAGE
  puts HELP
  exit
end

params["signature"] = generate_signature(api_secret, pcode, embed_code, hashing_method, params)

player_token = generate_token(server, pcode, embed_code, params)

puts "\nEmbed Token: \n" + player_token