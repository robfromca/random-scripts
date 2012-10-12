#!/usr/bin/ruby
require 'optparse'

options = {}

def log(message, options)
  if options[:verbose]
    puts "DEBUG: " + message
  end
end    

optparse = OptionParser.new do |opts|
	opts.banner = "Usage: vpn-charles.rb\n Copies proxy settings from your active connection to your juniper vpn settings."
	options[:verbose] = false
	opts.on( '-v', '--verbose', 'Spit out extra debugging info') do
		options[:verbose] = true
	end
	opts.on( '-a', '--on', 'Activate charles on your VPN' ) do
		options[:on] = true
	end
	opts.on( '-d', '--off', 'Deactivate charles on your VPN' ) do
		options[:on] = false
	end
	opts.on( '-h', '--help', 'Display this screen' ) do
		puts opts
		exit
	end
end

begin
	optparse.parse!
	onMissing = [:on].select{ |param| options[param].nil? }
	if not onMissing.empty? 
	puts "Must specify --on or --off"
	puts optparse
	exit
end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
       puts $!.to_s
       puts optparse
       exit
end

juniperState = `scutil<< EOF
show State:/Network/Service/net.juniper.ncproxyd.main/IPv4
quit
EOF`

log(juniperState, options)

serviceKey = juniperState.gsub(/.*net\.juniper\.DSUnderlyingServiceName : (.*?)\s.*/m, "\\1").chomp

log(serviceKey, options)

if options[:on]
  #now save it (must be root :-( )
results = `scutil<< EOF
lock
d.init
get Setup:/Network/Service/#{serviceKey}/Proxies
set State:/Network/Service/net.juniper.ncproxyd.main/Proxies
unlock
quit
EOF`
else
  # disable proxying
results = `scutil<< EOF
lock
d.init
get State:/Network/Service/net.juniper.ncproxyd.main/Proxies
d.add HTTPSEnable 0
d.add HTTPEnable 0
set State:/Network/Service/net.juniper.ncproxyd.main/Proxies
unlock
quit
EOF`
end


puts results

