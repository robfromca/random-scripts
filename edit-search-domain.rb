#!/usr/bin/ruby
require 'optparse'

options = {}

optparse = OptionParser.new do |opts|
	opts.banner = "Usage: edit-search-domain.rb [options] domainname"
	options[:verbose] = false
	opts.on( '-v', '--verbose', 'Spit out extra debugging info') do
		options[:verbose] = true
	end
	options[:add] = nil;
	opts.on( '-a', '--add DOMAIN', 'Add the supplied domain to the list') do |dom|
		options[:add] = dom
	end
	options[:remove] = nil;
	opts.on( '-r', '--remove DOMAIN', 'Remove the supplied domain from the list') do |dom|
		options[:remove] = dom
	end
	opts.on( '-h', '--help', 'Display this screen' ) do
		puts opts
		exit
	end
end

begin
	optparse.parse!
	addMissing = [:add].select{ |param| options[param].nil? }
	removeMissing = [:remove].select{ |param| options[param].nil? }
	if not addMissing.empty? || removeMissing.empty?
	puts "Must specify --add or --remove switches"
	puts optparse
	exit
end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
       puts $!.to_s
       puts optparse
       exit
end

allDNSKeys = `scutil<< EOF
list State:/Network/Service/[^/]+/DNS
quit
EOF`

dnsKeys = allDNSKeys.split("\n")

# We're on VPN so we want the juniper VPN resolver.
if dnsKeys[0] =~ /juniper/
	serviceKey = "State:/Network/Service/net.juniper.ncproxyd.main/DNS"
else # not on VPN, so we need to find the big GUID of the active network config
	serviceKey = dnsKeys[0]
	serviceKey = serviceKey.gsub!(/.*Service\/(.*)\/DNS/,"\\1").chomp
	serviceKey = "State:/Network/Service/#{serviceKey}/DNS" 
end
puts serviceKey
#Get our search domains
dnsQueryResults = `scutil<< EOF
get #{serviceKey}
d.show
quit
EOF`

# Okay, this is going to suck. Here's the format we're parsing:

#<dictionary> {
#  ServerAddresses : <array> {
#    0 : 10.184.129.101
#    1 : 10.184.129.102
#  }
#  SearchDomains : <array> {
#    0 : sea.corp.expecn.com
#    1 : expecndx.com
#    2 : idx.expedmz.com
#    3 : karmalab.net
#    4 : ad.hotwirebiz.com
#    5 : hotwirebiz.com
#    6 : hotwire.com
#    7 : classic.ccv.com
#    8 : 180096hotel.com
#    9 : lvx.corp.expecn.com
#    10 : prod.hotelscom.net
#  }
#}

# First let's a use a regex to get everything for SearchDomains:
rawSearchDomains = dnsQueryResults.gsub(/.*SearchDomains : <array> \{\n(.*?)\}.*\}/m, "\\1")
# Now let's hit the individual lines
domains = []
rawSearchDomains.each do |line|
	if line =~ /\S/
		domain = line.split(":")[1]
		domains.push(domain.strip!)
	end
end

# add our domain the user wanted to add (oh yeah, we were doing something here)
if options[:add]
   domains.push options[:add]
elsif options[:remove]
   domains.delete_if { |domain| domain == options[:remove] }
end
p domains
domainsWithSpaces = domains.join(" ")
addCommand = "d.add SearchDomains * " + domainsWithSpaces

#now save it (must be root :-( )

addResults = `scutil<< EOF
d.init
get #{serviceKey}
#{addCommand}
set #{serviceKey}
quit
EOF`

puts addResults

