#!/usr/bin/ruby
require 'optparse'

options = {}

def log(message, options)
  if options[:verbose]
    puts "DEBUG: " + message
  end
end    

def retrieveServiceKey(options, versionIdentifier)
  juniperState = `scutil<< EOF
  show State:/Network/Service/#{versionIdentifier}/IPv4
  quit
  EOF`

  log(juniperState, options)
  serviceKey = juniperState.gsub(/.*net\.pulsesecure\.DSUnderlyingServiceName : (.*?)\s.*/m, "\\1").chomp
  log(serviceKey, options)
  return serviceKey
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
	opts.on( '-o', '--old', 'Use for older versions of pulse' ) do
		options[:old] = true
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

versionIdentifier = "net.pulsesecure.pulse.nc.main"
if options[:old]
  versionIdentifier = "net.juniper.ncproxyd.main"
end

serviceKey = retrieveServiceKey(options, versionIdentifier)

if options[:on]
  puts "Please make sure your VPN is connected and Charles is running, then"
  puts "press any key to continue..."
  STDIN.gets

  #now save it (must be root :-( )
results = `scutil<< EOF
d.init
get Setup:/Network/Service/#{serviceKey}/Proxies
set State:/Network/Service/#{versionIdentifier}/Proxies
quit
EOF`
  puts "Charles should be recording now. Don't forget to run:"
  puts 
  puts "sudo ./vpn-charles.rb --off"
  puts 
  puts "to disable proxying when you either close charles or disconnect from the VPN"
else
  # disable proxying
results = `scutil<< EOF
d.init
get State:/Network/Service/#{versionIdentifier}/Proxies
d.add HTTPSEnable 0
d.add HTTPEnable 0
set State:/Network/Service/#{versionIdentifier}/Proxies
quit
EOF`
end

puts results

