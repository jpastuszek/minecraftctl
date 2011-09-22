require 'fcntl'

class Spawn
  def self.spawn(*cmd, &b)
    pw, pr, pe, ps = IO.pipe, IO.pipe, IO.pipe, IO.pipe

		ps.first.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
		ps.last.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

		cid = fork {
			pw.last.close
			STDIN.reopen pw.first
			pw.first.close

			pr.first.close
			STDOUT.reopen pr.last
			pr.last.close

			pe.first.close
			STDERR.reopen pe.last
			pe.last.close

			STDOUT.sync = STDERR.sync = true

			begin
				# WARNING: detect max open fd no - is thre a better way?
				r, w = IO.pipe
				max_fd = r.to_i - 1
				r.close
				w.close

				#puts "setting close on exec for fd's from 3 to #{max_fd}"
				(3..max_fd).each do |fd|
					begin
						IO.for_fd(fd).fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
						#puts "fd #{fd} set for closure on exec"
					rescue Errno::EBADF
					end
				end

				exec(*cmd)
				raise 'forty-two' 
			rescue Exception => e
				Marshal.dump(e, ps.last)
				ps.last.flush
			end
			ps.last.close unless (ps.last.closed?)
			exit!
		}

    [pw.first, pr.last, pe.last, ps.last].each{|fd| fd.close}

    begin
      e = Marshal.load ps.first
      raise(Exception === e ? e : "unknown failure!")
    rescue EOFError # If we get an EOF error, then the exec was successful
      42
    ensure
      ps.first.close
    end

    pw.last.sync = true

    pi = [pw.last, pr.first, pe.first]

    if b 
      begin
        b[cid, *pi]
        Process.waitpid2(cid).last
      ensure
        pi.each{|fd| fd.close unless fd.closed?}
      end
    else
      [cid, pw.last, pr.first, pe.first]
    end
  end
end

