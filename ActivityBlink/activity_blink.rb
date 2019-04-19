#!/usr/bin/ruby -w

module ActivityLED
	define_singleton_method(:check) do
		 (STDOUT.puts("Please run #{__FILE__} as root.\n\tReason: access to #{File.join('', 'dev', 'mem')} is needed.") || exit!(1))\
			unless File.readable?(File.join('', 'dev', 'mem'))

	        begin
        	        STDOUT.puts 'Requiring rpi_gpio'
        	        require 'rpi_gpio'

	       	 rescue LoadError => e
			require 'open3'
			STDOUT.print "#{e}\n\tWould you like to install it? (Y/n): "
			exit! 0 if STDIN.gets.strip.upcase == 'N'
			gem_install = Open3.capture2('sudo gem install rpi_gpio')
			exit!(gem_install[1].success? ? STDOUT.puts(gem_install[0]) || 0 : STDOUT.puts("Can't install rpi_gpio") || 1)
		end

		extend RPi::GPIO
	end

	define_singleton_method(:start_monitoring) do |pin = 7, sleep = 0.025, warnings = true|
		check unless defined?(set_warnings)

		set_warnings(warnings)
		set_numbering(:board)
		setup(pin, as: :output)

		begin
			loop do
				::IO.readlines('/proc/diskstats')[8..-1].map(&:split).select { |v| v[2].match(/(sd.|mmcblk\dp)[1-9]/)  }
					.count { |v| v[11].to_i > 0 } > 0 ? set_low(pin) : set_high(pin)
				Kernel.sleep(sleep)
			end

		rescue Interrupt, ::SystemExit
			STDOUT.puts("\n\nCleaning up pin #{pin}")
			clean_up(pin)
			STDOUT.puts("Exiting")
			exit!(0)

		rescue Exception => e
			STDERR.puts(e)
			retry
		end
	end
end

if ARGV.include?('--help') || ARGV.include?('-h')
	puts <<~EOF
		#{__FILE__} helps you monitoring your HDD / SSD / MMC activity through GPIO pin of your Raspberry pi.
		It reads /proc/diskstats, and send output to a GPIO pin to set output as low or high if your storage device is busy.
		It will only work with mmc cards, and USB storage devices.

		Arguments:
			1. --help/-h			Shows this help.
			2. --pin=<val>/-p=<val>		Specify a pin number for GPIO output(Default: 7)
			3. --sleep=<val>/-s=<val>	Sleep for a specific time after every iteration (Default: 0.025)
	EOF
	exit! 0
end

pin = ARGV.select { |a| a.start_with?('--pin=') || a.start_with?('-p=') }[-1].to_s.split('=')
pin = pin[-1] ? pin[-1].to_i : 7

sleep = ARGV.select { |a| a.start_with?('--sleep=') || a.start_with?('-s=') }[-1].to_s.split('=')
sleep = sleep[-1] ? sleep[-1].to_f : 0.025

puts "Using Pin #{pin} as output...\nDelay time #{sleep}..."
puts <<~EOF if sleep.<(0.025)
	Using short sleep time will increase CPU usage, but #{__FILE__} will work better
	Use --sleep=val or -s=val to reduce the sleep time.
EOF

ActivityLED.check
ActivityLED.start_monitoring(pin, sleep)