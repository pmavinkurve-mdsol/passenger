#  Phusion Passenger - https://www.phusionpassenger.com/
#  Copyright (c) 2010-2014 Phusion
#
#  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
#
#  See LICENSE file for license information.

module PhusionPassenger
module Utils

class Lock
	def initialize(mutex)
		@mutex = mutex
		@locked = false
	end

	def reset(mutex, lock_now = true)
		unlock if @locked
		@mutex = mutex
		lock if lock_now
	end

	def synchronize
		lock if !@locked
		begin
			yield(self)
		ensure
			unlock if @locked
		end
	end

	def lock
		raise if @locked
		@mutex.lock
		@locked = true
	end

	def unlock
		raise if !@locked
		@mutex.unlock
		@locked = false
	end
end

end # module Utils
end # module PhusionPassenger
