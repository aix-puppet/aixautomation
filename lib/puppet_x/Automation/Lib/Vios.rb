require_relative './Constants.rb'
require 'fileutils'
require 'yaml'

# #########################################################################
# Automation::Lib
# #########################################################################

module Automation
  module Lib

    # #########################################################################
    # Class Vios
    # #########################################################################
    class Vios

      # ########################################################################
      # name : get_journal_vios_file_name
      # param : input:vios:string vios name
      # param : input:clean:boolean to indicate to reset file contents.
      # return : file name
      # description : common function to build full path name of journal
      #  VIOS file according to VIOS name
      # One file per VIOS stores all journal information related to this VIOS
      #  during the vios_update process to help support and debug.
      # ########################################################################
      def self.get_journal_vios_file_name(vios, clean = false)
        # Log.log_debug('get_journal_vios_file_name vios=' + vios.to_s)
        journal_vios_file_dir = ::File.join(Constants.output_dir, 'vios')
        Utils.check_directory(journal_vios_file_dir)
        journal_vios_file_name = ::File.join(journal_vios_file_dir, "journal_#{vios}.log")
        if clean
          journal_info = []
          File.write(journal_vios_file_name, journal_info.to_yaml)
          Log.log_info('Refer to "' + journal_vios_file_name +
                           '" to have a journalized view of what was done on "' + vios + '" vios.')
        end
        journal_vios_file_name
      end

      # ########################################################################
      # name : get_updateios_output_vios_file_name
      # param : input:vios:string vios name
      # param : input:step:string either autocommit or update
      # return : file name
      # One file per VIOS stores NIM updateios output (one per autocommit, and
      #   one for update)
      # ########################################################################
      def self.get_updateios_output_file_name(vios,
          step = 'update')
        updateios_output_dir = ::File.join(Constants.output_dir, 'vios')
        Utils.check_directory(updateios_output_dir)
        updateios_output_file = ::File.join(updateios_output_dir,
                                            'NIM_UPDATEIOS_output_' + step + '_' + vios + '.log ')
        updateios_output_file
      end

      # ########################################################################
      # name : add_vios_journal_msg
      # param : input:vios:string VIOS name
      # param : input:msg:string message containing VIOS status
      # param : input:clean:string boolean to indicate to reset file
      # return : nothing
      # description : common function to add information related to one VIOS
      #  into its journal file.
      # One journal file per VIOS stores all information related to
      #  this VIOS during the vios_update process to help support and debug.
      # ########################################################################
      def self.add_vios_journal_msg(vios, msg, clean = false)
        journal_vios_file_name = Vios.get_journal_vios_file_name(vios, clean)
        journal_vios_info = []
        if File.exist?(journal_vios_file_name) and !clean
          journal_vios_info = YAML.load_file(journal_vios_file_name)
        end
        journal_vios_info.push(msg)
        File.write(journal_vios_file_name, journal_vios_info.to_yaml)
      end

      # ########################################################################
      # name : check_vios
      # param :input:vios:string vios
      # return : true if vios is valid, false if vios is invalid
      # description : checks 'vios' param
      #  Each vios is checked against the list of valid vios checked
      #  by vios facter.
      # ########################################################################
      def self.check_vios(vios)
        Log.log_debug('Into check_vios vios=' + vios.to_s)
        b_ret = true
        valid_vios = Facter.value(:vios)
        valid_vios_keys = valid_vios.keys
        # Log.log_info('valid_vios=' + valid_vios.to_s +
        #  ' valid_vios_keys=' + valid_vios_keys.to_s)
        Log.log_info('valid_vios_keys=' + valid_vios_keys.to_s)
        unless valid_vios_keys.include?(vios)
          b_ret = false
        end
        Log.log_debug('Into check_vios vios=' + vios.to_s + ' returns ' + b_ret.to_s)
        b_ret
      end


      # ########################################################################
      # name : check_input_vios_pair
      # param :input:vios_pair:array of two vios
      # param :output:kept:array of array of two strings
      # param :output:suppressed:array of array of two strings
      # return : 2 output params
      # description : checks 'vios_pair' array, if both vios are valid, then
      #   add 'vios_pair' into 'kept', otherwise add 'vios_pair' into 'suppressed'
      # ########################################################################
      def self.check_input_vios_pair(vios_pair,
          kept,
          suppressed)
        Log.log_debug('Into check_input_vios_pair vios_pair=' + vios_pair.to_s +
                          ' kept=' + kept.to_s +
                          ' suppressed=' + suppressed.to_s)
        b_suppressed = false
        validity_vios = {}
        vios_pair.each do |vios|
          # Log.log_info('valid_vios_keys=' + valid_vios_keys.to_s +
          #  ' vios=' + vios + ' include=' + (valid_vios_keys.include?(vios)).to_s)
          msg = 'Launch of VIOS udate on "' + vios.to_s + '" vios.'
          Vios.add_vios_journal_msg(vios, msg, true)
          # Each vios is checked against the list of valid vios checked by vios facter
          validity_vios[vios] = Vios.check_vios(vios)
          unless validity_vios[vios]
            b_suppressed = true
            suppressed.push(vios_pair)
          end
        end

        vios_pair.each do |vios|
          if b_suppressed
            if validity_vios[vios]
              msg = "The \"#{vios}\" vios of the \"#{vios_pair}\" pair \
is part of 'vios' facter, but the other vios of the pair is not, \
and therefore this \"#{vios_pair}\" vios_pair cannot be kept."
              Log.log_warning(msg)
              Vios.add_vios_journal_msg(vios, msg)
            else
              msg = "The \"#{vios}\" vios of the \"#{vios_pair}\" pair \
is not part of 'vios' facter, and therefore this \"#{vios_pair}\" vios_pair cannot be kept."
              Log.log_warning(msg)
              Vios.add_vios_journal_msg(vios, msg)
            end
          end
        end

        #
        unless b_suppressed
          msg = "VIOS of #{vios_pair}\" pair \
have been tested ok, and therefore this vios_pair is kept."
          Log.log_info(msg)
          kept.push(vios_pair)
          vios_pair.each do |vios|
            Vios.add_vios_journal_msg(vios, msg)
          end
        end
        kept.uniq!
        suppressed.uniq!
        Log.log_debug('Ending check_input_vios_pair suppressed=' + suppressed.to_s + ' kept=' + kept.to_s)
      end

      # ##################################################################
      # Check that the '/usr/sbin/vioshc.py' script can be used
      # Return: 0 if success
      # Raise: ViosHealthCheckError in case of error
      # ##################################################################
      def self.check_vioshc
        Log.log_debug('check_vioshc')
        vioshc_file = '/usr/sbin/vioshc.py'

        unless ::File.exist?(vioshc_file)
          msg = "Error: Health check script file '#{vioshc_file}': not found"
          raise ViosHealthCheckError, msg
        end

        unless ::File.executable?(vioshc_file)
          msg = "Error: Health check script file '#{vioshc_file}' not executable"
          raise ViosHealthCheckError, msg
        end

        Log.log_debug('check_vioshc ok')
        return 0
      end

      # ##################################################################
      # name : vios_health_init
      # param : in:nim_vios:hashtable
      # param : in:hmc_id:string
      # param : in:hmc_ip:string
      # return : 0 or 1 depending if the test is ok or not
      # description : VIOSCheck is composed of two methods:
      #   - vios_health_init
      #   - vios_health_check
      #  This first method collects UUIDs (VIOS and Managed System UUIDs).
      #  This operation uses 'vioshc.py' script to collect UUID, these
      #   info are persisted into yml file.
      # ##################################################################
      def self.vios_health_init(nim_vios,
          hmc_id,
          hmc_ip)
        Log.log_debug("vios_health_init: nim_vios='#{nim_vios}' hmc_id='#{hmc_id}', hmc_ip='#{hmc_ip}'")
        ret = 0

        # Info retrieved by health init will be persisted into yml file
        vios_kept_and_init_file = ::File.join(Constants.output_dir,
                                              'vios',
                                              'vios_kept_and_init.yml')

        # Info are retrieved using '/usr/sbin/vioshc.py' script
        cmd_s = "/usr/sbin/vioshc.py -i #{hmc_ip} -l a"
        # Add verbose
        cmd_s << " -v "
        Log.log_info("vios_health_init: calling command '#{cmd_s}' to retrieve vios_uuid and cec_uuid")

        Open3.popen3({'LANG' => 'C'}, cmd_s) do |_stdin, stdout, stderr, wait_thr|
          stderr.each_line do |line|
            # Nothing is printed on stderr so far but log anyway
            Log.log_err("[STDERR] #{line.chomp}")
          end
          unless wait_thr.value.success?
            stdout.each_line {|line| Log.log_info(" #{line.chomp}")}
            Log.log_err("vios_health_init: calling command '#{cmd_s}' to retrieve vios_uuid and cec_uuid")
            return 1
          end

          managed_system_section = 0
          vios_section = 0

          # Parse the output and store the UUIDs
          b_found_cec = false
          found_vios = 0
          stdout.each_line do |line|
            # Remove any space before and after
            line.strip!
            Log.log_debug(" #{line.chomp}")
            if line.include?("ERROR") || line.include?("WARN")
              # Needed this because vioshc.py script does not prints error to stderr
              Log.log_warning("[WARNING] vios_health_init: (vioshc.py) script: '#{line.strip}'")
              next
            end

            # New managed system section
            if managed_system_section == 0
              if line =~ /(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})\s+(\w{4}-\w{3}\*\w{7})/
                Log.log_debug('vios_health_init: start of MS section')
                managed_system_section = 1
                cec_uuid = Regexp.last_match(1)
                cec_serial = Regexp.last_match(2)
                nim_vios.keys.each do |vios_key|
                  if nim_vios[vios_key]['mgmt_cec_serial2'] == cec_serial
                    nim_vios[vios_key]['cec_uuid'] = cec_uuid
                    unless b_found_cec
                      msg = "To perform vioshc on \"#{vios_key}\" vios, we successfully retrieved cec_uuid='#{cec_uuid}' and cec_serial='#{cec_serial}'"
                      Log.log_info(msg)
                      Vios.add_vios_journal_msg(vios_key, msg)
                      b_found_cec = true
                    end
                  end
                end
                next
              else
                next
              end
            else
              if vios_section == 0
                if line =~ /^VIOS\s+Partition\sID$/
                  vios_section = 1
                  Log.log_debug('vios_health_init: start of VIOS section')
                  next
                else
                  next
                end
              else
                if line =~ /^$/
                  Log.log_debug('vios_health_init: end of VIOS section')
                  Log.log_debug('vios_health_init: end of MS section')
                  managed_system_section = 0
                  vios_section = 0
                  b_found_cec = false
                  next
                else
                  if b_found_cec
                    if line =~ /(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})\s+(\w+)/
                      vios_uuid = Regexp.last_match(1)
                      vios_part_id = Regexp.last_match(2)
                      Log.log_debug('vios_uuid=' + vios_uuid + ' vios_part_id=' + vios_part_id)
                      # Retrieve the vios with the vios_part_id and the cec_serial value
                      # and store the UUIDs in the dictionaries
                      if b_found_cec
                        nim_vios.keys.each do |vios_key|
                          if nim_vios[vios_key]['mgmt_vios_id'] == vios_part_id
                            nim_vios[vios_key]['vios_uuid'] = vios_uuid
                            msg = "To perform vioshc on \"#{vios_key}\" vios, we successfully retrieved vios_part_id='#{vios_part_id}' and vios_uuid='#{vios_uuid}'"
                            Log.log_info(msg)
                            Vios.add_vios_journal_msg(vios_key, msg)
                            found_vios += 1
                            break
                          end
                        end
                        if found_vios == 2
                          break
                        end
                      end
                      next
                    else
                      next
                    end
                  end
                end
              end
            end
          end

          # Information retrieved are persisted into yaml file
          File.write(vios_kept_and_init_file, nim_vios.to_yaml)
          Log.log_info('Refer to "' + vios_kept_and_init_file.to_s + '" to have full results of "vios_health_init".')
        end

        ret
      end

      # ##################################################################
      # name : vios_health_check
      # param : in:nim_vios:hashtable
      # param : in:hmc_ip:string
      # param : in:vios_list:string
      # return : 0 or 1 depending if the test is ok or not
      # description : VIOSCheck is composed of two methods:
      #   - vios_health_init
      #   - vios_health_check
      #  This second method performs health check.
      #  This operation uses 'vioshc.py' script to evaluate the capacity
      #   of the pair of the VIOSes to support the rolling update operation:
      #  Health assessment of the VIOSes targets to ensure they can support
      #   a rolling update operation.
      # ##################################################################
      def self.vios_health_check(nim_vios,
          hmc_ip,
          vios_list)
        Log.log_debug("vios_health_check: hmc_ip: #{hmc_ip} vios_list: #{vios_list}")
        ret = 0
        rate = 0

        cmd_s = "/usr/sbin/vioshc.py -i #{hmc_ip} -m #{nim_vios[vios_list[0]]['cec_uuid']} "
        vios_list.each do |vios|
          cmd_s << "-U #{nim_vios[vios]['vios_uuid']} "
        end
        # add verbose
        cmd_s << " -v "
        Log.log_info("vios_health_check: calling command '#{cmd_s}' to perform health check")

        Open3.popen3({'LANG' => 'C'}, cmd_s) do |_stdin, stdout, stderr, wait_thr|
          stderr.each_line do |line|
            Log.log_err("[STDERR] #{line.chomp}")
          end
          ret = 1 unless wait_thr.value.success?

          # Parse the output to get the "Pass rate"
          stdout.each_line do |line|
            Log.log_info(" #{line.chomp}")

            if line.include?("ERROR") || line.include?("WARN")
              # Need because vioshc.py script does not prints error to stderr
              Log.log_warning("Health check (vioshc.py) script: '#{line.strip}'")
            end
            next unless line =~ /Pass rate of/

            rate = Regexp.last_match(1).to_i if line =~ /Pass rate of (\d+)%/

            if ret == 0 && rate == 100
              msg = "Vios pair \"#{vios_list.join('-')}\" has been successfully checked with vioshc, and can be updated"
              Log.log_info(msg)
              vios_list.each do |vios_item|
                Vios.add_vios_journal_msg(vios_item, msg)
              end
            else
              msg = "Vios pair \"#{vios_list.join('-')}\" can NOT be updated: only #{rate}% of checks pass"
              Log.log_warning(msg)
              vios_list.each do |vios_item|
                Vios.add_vios_journal_msg(vios_item, msg)
              end
              ret = 1
            end
            break
          end
        end

        ret
      end


      # ########################################################################
      # name : find_best_alt_disk_vios
      # param : in:vios: vios name on which we may
      #  desire performing alt_disk_copy
      # param : in:hvios: hastable with "0" and "1" keys.
      #    "0" key contains an array with vios without altinst_rootvg
      #    "1" key contains an array with vios with    altinst_rootvg
      #    altinst_rootvg (if it exists on a vios) can be removed and
      #      its disk reused.
      # param : in:actions: list of actions enables by user.
      # param : in:chosen_disk: name of the disk chosen by user. My be empty
      #    If set we try to use this one as first choice, if it fits, if it
      #    does not fit, we do as this parameter was not set.
      # param : in:nb_of_pp: number of physical partitions
      #    of rootvg, to get the size of rootvg we need to multiply by the size
      #    of one physical partition..
      # param : in:altinst_rootvg_force: yes or no. If set to yes, it indicates that
      #    altinst_rootvg (if it exists) can be removed and its disk reused.
      #    If set to no, existing altinst_rootvg is not touched.
      # return : an array containing three strings: name,pvid,size
      # description : for vios in input parameter, find the best free disk
      #   to perform alt_fisk_copy, this disk needs to be free, be large enough
      #   to contain rootvg of vios, but the smaller one of all possible disks
      #   should be chosen.
      # ########################################################################
      def self.find_best_alt_disk_vios(vios,
          hvios,
          actions,
          chosen_disk,
          nb_of_pp,
          altinst_rootvg_force)
        Log.log_debug('find_best_alt_disk_vios for "' + vios.to_s +
                          '" vios with hvios=' + hvios.to_s +
                          ' with actions=' + actions.to_s +
                          ' with chosen_disk=' + chosen_disk.to_s +
                          ' with nb_of_pp=' + nb_of_pp.to_s +
                          ' with force=' + altinst_rootvg_force.to_s)
        vios_returned = []

        #
        if altinst_rootvg_force.to_s == 'reuse' and hvios["1"].include? vios
          # If an altinst_rootvg already exists, we reuse it
          # There is no need to remove previous one, and to find the best
          #  disk to do it
          msg = 'We reuse existing altinst_rootvg on ' + vios.to_s
          Log.log_info(msg)
          Vios.add_vios_journal_msg(vios, msg)
          vios_returned.push(vios)
        else
          # This 'else' covers the following cases :
          #  - altinst_rootvg_force.to_s == 'reuse' and !hvios["1"].include? vios
          #  - altinst_rootvg_force.to_s == 'yes'
          #  - altinst_rootvg_force.to_s == 'no'
          Log.log_info('find_best_alt_disk_vios on: ' + vios.to_s)
          alt_disk_to_reuse = []
          Log.log_info('Call to altvg_find_and_remove: ' + vios.to_s)
          ret = Vios.altvg_find_and_remove(vios, actions, alt_disk_to_reuse)
          if ret == 0
            Log.log_info('There was an altinst_rootvg on ' + vios.to_s + ' which has been cleaned.')
          end

          Log.log_info('find_best_alt_disks on: ' + vios.to_s)
          size_rootvg, size_used_rootvg, size_pp = Vios.get_vg_size(vios, 'rootvg')
          Log.log_info('find_best_alt_disk_vios on: ' + vios.to_s +
                           ' rootvg size: ' + size_rootvg.to_s +
                           ' rootvg used size:' + size_used_rootvg.to_s +
                           ' partition size:' + size_pp.to_s)
          computed_size_rootvg = size_pp * nb_of_pp
          Log.log_info('computed_size_rootvg: ' + computed_size_rootvg.to_s)
          #
          if size_used_rootvg.to_i != 0
            remote_cmd1 = "/usr/ios/cli/ioscli lspv -free | /bin/grep -v NAME"
            remote_output1 = []
            remote_cmd_rc1 = Remote.c_rsh(vios, remote_cmd1, remote_output1)
            if remote_cmd_rc1 == 0
              added = 0
              if !remote_output1[0].nil? and !remote_output1[0].empty?
                Log.log_debug('remote_output1[0]=' + remote_output1[0].to_s)
                remote_output1_lines = remote_output1[0].split("\n")
                Log.log_debug('remote_output1_lines=' + remote_output1_lines.to_s)
                # As there might be several disks possible, in a first pass we
                #  keep them into disks_kept, and in a second pass we'll select
                #  smaller one
                disks_kept = []
                remote_output1_lines.each do |remote_output1_line|
                  Log.log_debug('remote_output_lines=' + remote_output1_line.to_s)
                  name_candidate_disk, pvid_candidate_disk, size_candidate_disk = remote_output1_line.split
                  Log.log_debug("name_candidate_disk= #{name_candidate_disk} \
pvid_candidate_disk=#{pvid_candidate_disk} \
size_candidate_disk=#{size_candidate_disk}")
                  if computed_size_rootvg.to_i < size_candidate_disk.to_i
                    disks_kept.push([name_candidate_disk, size_candidate_disk])
                    added += 1
                  end
                end
                #
                if added != 0
                  name_candidate_disk = ''
                  if !chosen_disk.nil? and
                      !chosen_disk.empty? and
                      disks_kept.include? chosen_disk
                    # If one disk was explicitly chosen by user and
                    #  this disk is par of the disks_kept list,
                    #  we take this one.
                    name_candidate_disk = chosen_disk
                  elsif !alt_disk_to_reuse.nil? and
                      !alt_disk_to_reuse.empty? and
                      disks_kept.include? alt_disk_to_reuse[0]
                    # If there was one disk previously used for altinst_rootvg
                    #  and this disk is still into the list of possible disks,
                    #  we take this one.
                    name_candidate_disk = alt_disk_to_reuse[0]
                  else
                    # If there was no disk previously used for altinst_rootvg
                    # If there is one or several disks kept
                    #  we keep only the smaller one
                    min = disks_kept[0][1]
                    Log.log_info("disks_kept=" + disks_kept.to_s + ' min=' + min.to_s)
                    disks_kept.each do |disk_kept|
                      if disk_kept[1].to_i <= min.to_i
                        Log.log_info("disk_kept=" + disk_kept.to_s + ' min=' + min.to_s)
                        min = disk_kept[1]
                        name_candidate_disk = disk_kept[0]
                      end
                    end
                  end
                  msg = "Best disk to perform alt_disk_install operation on #{vios} is #{name_candidate_disk}"
                  Log.log_info(msg)
                  Vios.add_vios_journal_msg(vios, msg)
                  vios_returned.push(vios)
                  vios_returned.push(name_candidate_disk)
                end
              else
                Log.log_err('find_best_alt_disk_vios: no free disk')
                vios_returned.push(vios)
              end
            else
              Log.log_err('find_best_alt_disk_vios: cannot get free disk')
              vios_returned.push(vios)
            end
          else
            Log.log_err('find_best_alt_disk_vios: rootvg size = 0?')
            vios_returned.push(vios)
          end
        end
        #
        Log.log_debug('find_best_alt_disk_vios on: ' + vios.to_s + ' returning:' + vios_returned.to_s)
        vios_returned
      end


      # ########################################################################
      # name : get_vg_size
      # param : in:vios:string
      # param : in:vg_name:string
      # return : [size1,size2]
      # description : returns the total size, the used vg size, and the
      #  partition size in megabytes
      # ########################################################################
      def self.get_vg_size(vios,
          vg_name)
        Log.log_debug('get_vg_size on ' + vios.to_s + ' for ' + vg_name.to_s)
        vg_size = 0
        used_size = 0
        pp_size = 0
        remote_cmd1 = '/usr/ios/cli/ioscli lsvg ' + vg_name.to_s
        remote_output1 = []
        remote_cmd_rc1 = Remote.c_rsh(vios, remote_cmd1, remote_output1)
        if remote_cmd_rc1 == 0
          Log.log_debug('remote_output1[0] ' + remote_output1[0].to_s)
          # stdout is like:
          # parse lsvg output to get the size in megabytes:
          # VG STATE:      active      PP SIZE:   512 megabyte(s)
          # VG PERMISSION: read/write  TOTAL PPs: 558 (285696 megabytes)
          # MAX LVs:       256         FREE PPs:  495 (253440 megabytes)
          # LVs:           14          USED PPs:   63 (32256 megabytes)
          remote_output1[0].each_line do |line|
            Log.log_debug(" #{line.chomp}")
            line.chomp!
            if line =~ /.*TOTAL PPs:\s+\d+\s+\((\d+)\s+megabytes\).*/
              vg_size = Regexp.last_match(1).to_i
            elsif line =~ /.*USED PPs:\s+\d+\s+\((\d+)\s+megabytes\).*/
              used_size += Regexp.last_match(1).to_i
            elsif line =~ /.*PP SIZE:\s+(\d+)\s+megabyte\(s\).*/
              pp_size += Regexp.last_match(1).to_i
            end
          end
        else
          Log.log_err("Failed to get Volume Group '#{vg_name}' size: on #{vios}")
        end
        if vg_size == 0 || used_size == 0
          Log.log_err("Failed to get Volume Group '#{vg_name}' size: TOTAL PPs=#{vg_size}, USED PPs+1=#{used_size}, PP SIZE=#{pp_size} MB on #{vios}")
          [0, 0, 0]
        else
          Log.log_info("VG '#{vg_name}' TOTAL PPs=#{vg_size} MB, USED PPs+1=#{used_size} MB, PP SIZE=#{pp_size} MB")
          [vg_size, used_size, pp_size]
        end
      end


      # ##################################################################
      # name : perform_alt_disk_install
      # param : in:vios:string
      # param : in:disk:string
      # param : in:set_bootlist:string
      # param : in:boot_client:string
      # return : 0 if ok, 1 otherwise
      # description : Run the NIM alt_disk_install command to launch
      #  the alternate copy operation on specified vios
      # ##################################################################
      def self.perform_alt_disk_install(vios,
          disk,
          set_bootlist = 'no',
          boot_client = 'no')
        Log.log_debug("perform_alt_disk_install: vios: #{vios} disk: #{disk}")
        ret = 0
        cmd = "/usr/sbin/nim -o alt_disk_install -a source=rootvg -a disk=#{disk} \
-a set_bootlist=#{set_bootlist} -a boot_client=#{boot_client} #{vios}"
        Log.log_debug("perform_alt_disk_install: '#{cmd}'")
        Open3.popen3({'LANG' => 'C'}, cmd) do |_stdin, stdout, stderr, wait_thr|
          stdout.each_line {|line| Log.log_debug(" #{line.chomp}")}
          stderr.each_line do |line|
            Log.log_err("[STDERR] #{line.chomp}")
            ret = 1
          end
          Log.log_debug("perform_alt_disk_install: #{wait_thr.value}") # Process::Status object
        end
        ret
      end


      # ##################################################################
      # Wait for the alternate disk copy operation to finish
      #
      # when alt_disk_install operation ends the NIM object state changes
      # from "a client is being prepared for alt_disk_install" or
      #      "alt_disk_install operation is being performed"
      # to   "ready for NIM operation"
      #
      # You might want a timeout of 30 minutes (count=90, sleep=20s), if
      # there is no progress in NIM operation "info" attribute for this
      #  duration, it can be considered as an error. Manual intervention
      #  is required in that case.
      #
      # Returns
      #    0   if the alt_disk_install operation ends with success
      #    1   if the alt_disk_install operation failed
      #    -1  if the alt_disk_install operation timed out
      # ##################################################################
      def self.wait_alt_disk_install(vios,
          check_count = 90,
          sleep_time = 20)
        nim_info_prev = '___' # this info should not appear in nim info attribute
        nim_info = ''
        count = 0
        wait_time = 0
        ret = 0
        cmd_s = "/usr/sbin/lsnim -Z -a Cstate -a info -a Cstate_result #{vios}"
        Log.log_info('wait_alt_disk_install: ' + cmd_s.to_s)

        while count <= check_count do
          sleep(sleep_time)
          wait_time += 20
          nim_cstate = ''
          nim_result = ''
          nim_info = ''

          Open3.popen3({'LANG' => 'C'}, cmd_s) do |_stdin, stdout, stderr, wait_thr|
            stderr.each_line do |line|
              Log.log_err("[STDERR] #{line.chomp}")
            end
            unless wait_thr.value.success?
              stdout.each_line {|line| Log.log_info(" #{line.chomp}")}
              Log.log_err('Failed to get the NIM state for vios ' + vios.to_s + ', see above error!')
              ret = 1
            end

            if ret == 0
              stdout.each_line do |line|
                Log.log_debug(" #{line.chomp}")
                # info attribute (that appears in 3rd position) can be empty. So stdout looks like:
                # #name:Cstate:info:Cstate_result:
                # <viosName>:ready for a NIM operation:success:  -> len=3
                # <viosName>:alt_disk_install operation is being performed:Creating logical volume alt_hd2.:success:  -> len=4
                # <viosName>:ready for a NIM operation:0505-126 alt_disk_install- target disk hdisk2 has a volume group assigned to it.:failure:  -> len=4
                nim_status = line.strip.split(':')
                if nim_status[0] != "#name"
                  Log.log_info("\033[2K\r#{nim_status[2]}")
                  Log.log_info("nim_status:#{nim_status}")
                else
                  next
                end

                nim_cstate = nim_status[1]
                if nim_status.length == 3 && (nim_status[2].downcase == "success" || nim_status[2].downcase == "failure")
                  nim_result = nim_status[2].downcase
                elsif nim_status.length > 3
                  nim_info = nim_status[2]
                  nim_result = nim_status[3].downcase
                else
                  Log.log_warning("[#{vios}] Unexpected output #{nim_status} for command '#{cmd_s}'")
                end

                if nim_cstate.downcase == 'ready for a nim operation'
                  unless nim_result == 'success'
                    msg = "Failed to perform NIM alt_disk_install operation on \"#{vios}\" vios: #{nim_info}"
                    Log.log_err(msg)
                    Vios.add_vios_journal_msg(vios, msg)
                    return 1
                  end
                  Log.log_info("\033[2K\r")
                  msg = "NIM alt_disk_install operation on \"#{vios}\" vios succeeded"
                  Log.log_info(msg)
                  Vios.add_vios_journal_msg(vios, msg)
                  return 0 # here the operation succeeded
                else
                  if nim_info_prev == nim_info
                    count += 1
                  else
                    nim_info_prev = nim_info unless nim_info.empty?
                    count = 0
                  end
                end
                if wait_time.modulo(60) == 0
                  msg = "Waiting for the NIM alt_disk_install on #{vios}, duration: #{wait_time / 60} minute(s)"
                  Log.log_info("\033[2K\r#{msg}")
                end
              end
            end
          end
        end # while count

        # Timed out before the end of alt_disk_install
        msg = "NIM alt_disk_install operation for #{vios} shows no progress in #{count * sleep_time / 60} minute(s): #{nim_info}"
        Log.log_err(msg)
        Vios.add_vios_journal_msg(vios, msg)
        return -1
      end


      # ########################################################################
      # name : check_altinst_rootvg_vios
      # param : in:vios:string containing one vios
      # description : check there is one altinst_rootvg
      #  on specified vios
      # return: either 0 or 1
      #   0 : if vios does not have altinst_rootvg
      #   1 : if vios has one altinst_rootvg
      # ########################################################################
      def self.check_altinst_rootvg_vios(vios)
        Log.log_debug('check_altinst_rootvg_vios on ' + vios.to_s)
        Log.log_info('Is there any existing altinst_rootvg on ' + vios.to_s + '?')
        ret = 0
        remote_cmd0 = '/usr/sbin/lspv | /bin/grep -w altinst_rootvg'
        remote_output0 = []
        remote_cmd_rc0 = Remote.c_rsh(vios, remote_cmd0, remote_output0)
        if remote_cmd_rc0 == 0
          if !remote_output0[0].nil? and !remote_output0[0].empty?
            Log.log_debug('remote_output0[0]=' + remote_output0[0].to_s)
            ret = 1
          else
            Log.log_info('No altinst_rootvg on ' + vios.to_s)
            ret = 0
          end
        else
          Log.log_info('No altinst_rootvg on ' + vios.to_s)
          ret = 0
        end
        ret
      end


      # ########################################################################
      # name : check_altinst_rootvg
      # param : in:vios_pair:string containing one pair of vios
      #  (vios1,vios2)
      # description : check there is one altinst_rootvg
      #  on specified vios
      # return: hashtable with two keys
      #   key="0" contains list of vios on which there is no altinst_rootvg
      #   key="1" contains list of vios on which there is one altinst_rootvg
      # ########################################################################
      def self.check_altinst_rootvg_pair(vios_pair)
        Log.log_debug('check_altinst_rootvg_pair on ' + vios_pair.to_s)
        # prepare return value
        hret = {}
        hret["0"] = []
        hret["1"] = []
        vios_pair.each do |vios|
          if check_altinst_rootvg_vios(vios) == 0
            hret["0"] << vios
          else
            hret["1"] << vios
          end
        end
        Log.log_debug('check_altinst_rootvg_pair on ' + vios_pair.to_s + ' returning ' + hret.to_s)
        hret
      end


      # ########################################################################
      # name : check_altinst_rootvg_pairs
      # param : in:vios_pairs:string containing pairs of vios
      #  (vios1,vios2),(vios3,vios4)
      # description : check there is one altinst_rootvg
      #  on specified vios
      # return: hashtable with two keys
      #   key="0" contains list of vios on which there is no altinst_rootvg
      #   key="1" contains list of vios on which there is one altinst_rootvg
      # ########################################################################
      def self.check_altinst_rootvg_pairs(vios_pairs)
        Log.log_debug('check_altinst_rootvg_pairs on ' + vios_pairs.to_s)
        # prepare return value
        hret = {}
        hret["0"] = []
        hret["1"] = []
        vios_pairs.each do |vios_pair|
          vios_pair.each do |vios|
            if check_altinst_rootvg_vios(vios) == 0
              hret["0"] << vios
            else
              hret["1"] << vios
            end
          end
        end
        Log.log_debug('check_altinst_rootvg_pairs on ' + vios_pairs.to_s + ' returning ' + hret.to_s)
        hret
      end


      # ########################################################################
      # name : altvg_find_and_remove
      # param : in:vios:string
      # param : in:actions:string list of actions enabled by user
      # param : out:used_alt_disk:string array containing in index 0 alt_disk
      #  to be reused
      # description : Perform the symmetric operation of the NIM
      #  alt_disk_install to remove and clean the alternate copy operation
      #  on specified vios. It cleans as well the 'old_rootvg' if it exists
      #  (this should done only on explicit option from the user).
      # return: 0 if ok, 1 otherwise
      # ########################################################################
      def self.altvg_find_and_remove(vios,
          actions,
          used_alt_disk)
        Log.log_debug('altvg_find_and_remove on ' + vios.to_s)
        ret = 1
        vgs = []
        if !actions.nil? and actions.include? 'gc'
          vgs = ['old_rootvg', 'altinst_rootvg']
        else
          vgs = ['altinst_rootvg']
        end

        vgs.each do |vg|
          ret = 1
          used_alt_disk[0] = ''
          Log.log_info('Is there any existing ' + vg + ' on ' + vios.to_s + '?')
          remote_cmd0 = '/usr/sbin/lspv | /bin/grep -w ' + vg
          remote_output0 = []
          remote_cmd_rc0 = Remote.c_rsh(vios, remote_cmd0, remote_output0)
          if remote_cmd_rc0 == 0
            if !remote_output0[0].nil? and !remote_output0[0].empty?
              remote_output0.each do |remote_output0_allinline|
                Log.log_debug('remote_output0_allinline=' + remote_output0_allinline.to_s)
                remote_output0_lines = remote_output0_allinline.split("\n")
                remote_output0_lines.each do |remote_output0_line|
                  Log.log_debug('remote_output0_line=' + remote_output0_line.to_s)
                  alt_disk_name, _junk1, _junk2, active = remote_output0_line.split
                  Log.log_debug('alt_disk_name=' + alt_disk_name.to_s)
                  Log.log_debug('active=' + active.to_s)
                  if active.nil? or active.empty?
                    Log.log_info('There is one existing ' + vg + ' on ' + vios.to_s + ' and we need to varyonvg it')
                    remote_cmd1 = '/usr/sbin/varyonvg ' + vg
                    remote_output1 = []
                    remote_cmd_rc1 = Remote.c_rsh(vios, remote_cmd1, remote_output1)
                    Log.log_debug('On this command ' + remote_cmd1.to_s +
                                      ', the ' + remote_cmd_rc1.to_s + ' return code and ' +
                                      remote_output1[0].to_s + ' output are not necessarily an error.')
                    ret = Vios.perform_vg_clean_and_free_disk(vios, vg, alt_disk_name)
                  else
                    Log.log_info('There is one existing  ' + vg + ' on ' + vios.to_s + ' but we dont need to varyonvg it')
                  end

                  # check again
                  remote_cmd2 = '/usr/sbin/lsvg ' + vg
                  remote_output2 = []
                  remote_cmd_rc2 = Remote.c_rsh(vios, remote_cmd2, remote_output2)
                  if remote_cmd_rc2 == 0
                    Log.log_info('There is an ' + vg + ' on ' + vios.to_s)
                    # Meaning vg exists, we then need to remove it
                    ret = Vios.perform_vg_clean_and_free_disk(vios, vg, alt_disk_name)
                    used_alt_disk[0] = alt_disk_name
                  end
                end
              end
            else
              Log.log_info('No ' + vg + ' on ' + vios.to_s)
            end
          else
            Log.log_info('No ' + vg + ' on ' + vios.to_s)
          end
        end
        Log.log_debug('altvg_find_and_remove on ' + vios.to_s + ' returning ' + ret.to_s)
        ret
      end


      # ########################################################################
      # name : unmirror_altcopy_mirror_vios
      # param : in:vios_best_disk:
      # param : in:vios_mirrors:
      # description : Perform the unmirror, then the alt_disk_copy, then the
      #  mirror
      # return: 0 is success, 1 otherwise
      # ########################################################################
      def self.unmirror_altcopy_mirror_vios(vios_best_disk,
          vios_mirrors)
        Log.log_debug('unmirror_altcopy_mirror_vios on ' + vios_best_disk.to_s + ' ' + vios_mirrors.to_s)
        ret = 0
        #
        # As already said, there must be 2 elements into vios_disk array :
        #  - first element is vios name
        #  - second element is best disk to use to perform alt_disk_copy

        if vios_best_disk.length > 1
          Log.log_info('We can attempt an alt_disk_copy on ' + vios_best_disk.to_s)
          Log.log_debug('vios_mirrors=' + vios_mirrors.to_s)
          Log.log_debug('vios_mirrors[vios_best_disk[0]]=' + vios_mirrors[vios_best_disk[0]].to_s)
          Log.log_debug('!vios_mirrors[vios_best_disk[0]].nil?=' + (!vios_mirrors[vios_best_disk[0]].nil?).to_s)
          unless vios_mirrors[vios_best_disk[0]].nil?
            Log.log_debug('vios_mirrors[vios_best_disk[0]].length=' + (vios_mirrors[vios_best_disk[0]].length).to_s)
            if vios_mirrors[vios_best_disk[0]].length > 1
              # If mirroring is active on the rootvg of this vios
              #  unmirroring needs to be done here
              # Vios.perform_unmirror(vios)
              # If unmirroring has been correctly done, we can go on
              #  otherwise we must give up
              Log.log_info('The rootvg of this vios is mirrored on ' + vios_best_disk.to_s)
              Log.log_info('Attempting now to perform unmirror of rootvg on ' + vios_best_disk.to_s)
              ret = Vios.perform_unmirror(vios_best_disk[0], 'rootvg')
              Log.log_info('Perform unmirror returns ' + ret.to_s)
              if ret != 0
                return ret
              end
            else
              # No need to un-mirror
              Log.log_info('No need to un-mirror on ' + vios_best_disk.to_s)
            end
          end

          Log.log_info('Attempting now an alt_disk_copy on ' + vios_best_disk.to_s)
          ret = Vios.perform_alt_disk_install(vios_best_disk[0], vios_best_disk[1])
          Log.log_info('Perform alt_disk_copy returns ' + ret.to_s)
          if ret == 0
            Log.log_info('Waiting for alt_disk_copy to be done')
            ret = Vios.wait_alt_disk_install(vios_best_disk[0])
            Log.log_info('Perform wait_alt_disk_copy returns ' + ret.to_s)
            if ret == -1
              msg = "Manual intervention is required to verify the NIM alt_disk_install operation for #{vios_best_disk} being done!"
              Log.log_err(msg)
              return ret
            else
              Log.log_debug('vios_mirrors=' + vios_mirrors.to_s)
              Log.log_debug('vios_mirrors[vios_best_disk[0]]=' + vios_mirrors[vios_best_disk[0]].to_s)
              Log.log_debug('!vios_mirrors[vios_best_disk[0]].nil?=' + (!vios_mirrors[vios_best_disk[0]].nil?).to_s)
              unless vios_mirrors[vios_best_disk[0]].nil?
                Log.log_info('Performing now back again mirroring of rootvg on ' + vios_best_disk.to_s)
                Log.log_debug('vios_mirrors[vios_best_disk[0]].length=' + (vios_mirrors[vios_best_disk[0]].length).to_s)
                if vios_mirrors[vios_best_disk[0]].length > 1
                  # if mirroring was active on the rootvg of this vios
                  #   and if unmirroring has been done
                  #  then we need to mirror again this rootvg
                  disk_copies = []
                  disk_copies.push(vios_mirrors[vios_best_disk[0]][2])
                  if vios_mirrors[vios_best_disk[0]].length > 2
                    disk_copies.push(vios_mirrors[vios_best_disk[0]][3])
                  end
                  Log.log_info('Attempting now to perform mirror of rootvg on ' + vios_best_disk.to_s)
                  Log.log_debug('disk_copies=' + disk_copies.to_s)
                  ret = Vios.perform_mirror(vios_best_disk[0],
                                            'rootvg',
                                            disk_copies)
                  Log.log_info('Perform mirror returns ' + ret.to_s)
                  Log.log_info('The rootvg of this vios was mirrored on ' + vios_best_disk.to_s)
                else
                  # No need to mirror as we didn't un-mirror
                  Log.log_info('No need to mirror as we didn t un-mirror on ' + vios_best_disk.to_s)
                end
              end
            end
          else
            # Alt_disk_copy failed
            Log.log_err('Alt_disk_copy failed')
            return ret
          end
        else
          # No need to attempt an alt_disk_copy as we only have one parameter
          Log.log_info('No need to attempt an alt_disk_copy on ' + vios_best_disk.to_s)
          Log.log_info('This is not an error')
        end
        ret
      end


      # ##################################################################
      # name : perform_vg_clean_and_free_disk
      # param : in:vios:string
      # param : in:vg:string name of vg, either altinst_rootvg or old_rootvg
      # param : in:alt_disk:string
      # description : Perform the symmetric operation of the NIM
      #  alt_disk_install to remove and clean the alternate copy
      #  operation on specified vios
      # Return: 0 if ok, 1 otherwise
      # ##################################################################
      def self.perform_vg_clean_and_free_disk(vios,
          vg,
          alt_disk)
        Log.log_debug('perform_vg_clean_and_free_disk: vios=' + vios.to_s +
                          ' vg=' + vg.to_s +
                          ' disk=' + alt_disk.to_s)
        ret = 0
        #
        Log.log_debug('Cleaning altinst_rootvg on ' + vios)
        # /usr/sbin/alt_rootvg_op -X altinst_rootvg => clean VG
        remote_cmd1 = '/usr/sbin/alt_rootvg_op -X ' + vg
        remote_output1 = ''
        remote_cmd_rc1 = Remote.c_rsh(vios, remote_cmd1, remote_output1)
        #
        if remote_cmd_rc1 == 0
          Log.log_info('Succeeded in removing ' + vg.to_s + ' on ' + vios.to_s)
        else
          ret = 1
          Log.log_err("#{remote_output1[0]}")
          Log.log_err('Failed to remove ' + vg.to_s + ' on ' + vios.to_s)
        end
        #
        if ret == 0
          #
          Log.log_debug('Cleaning disk ' + alt_disk.to_s + ' on ' + vios.to_s)

          # /etc/chdev -a pv=clear -l diskX  => remove PVID disk
          # /usr/bin/dd if=/dev/zero of=/dev/diskX seek=7 count=1 bs=512 => clean the disk and give it back to free
          remote_cmd2 = "/etc/chdev -a pv=clear -l #{alt_disk}; /usr/bin/dd if=/dev/zero of=/dev/#{alt_disk} seek=7 count=1 bs=512"
          remote_output2 = ''
          remote_cmd_rc2 = Remote.c_rsh(vios, remote_cmd2, remote_output2)
          if remote_cmd_rc2 == 0
            # Log.log_debug("#{remote_output2[0]}")
            Log.log_info('Succeeded in cleaning ' + vg.to_s + ' on ' + vios.to_s)
          else
            Log.log_err("#{remote_output2[0]}")
            Log.log_err('Failed to clean ' + vg.to_s + ' on ' + vios.to_s)
            ret = 1
          end
        end
        #
        Log.log_info('perform_vg_clean_and_free_disk: done, returning ' + ret.to_s)
        ret
      end


      # ########################################################################
      # name : check_rootvg_mirror
      # param : in:vios:string
      # param : out:copies:hash
      # param : out:nb_of_pp:[] first element of array
      #   contains the number of physical partitions of rootvg copy 1.
      # return : 0, 1, -1
      #   0 is returned if disk is not mirrored
      #   1 is returned if disk is mirrored and check is ok
      #  -1 is returned if disk is mirror but check is not ok
      # description : check if the rootvg is mirrored and if it is the case,
      #  that the mirror is not on same disk that the original. If it were
      #  the case, we wouldn't be able to un-mirror the rootvg, although this
      #  operation is mandatory before performing al_disk_copy.
      # This check_rootvg_mirror is as well the opportunity to count the
      #  number of physical partitions of the first copy (the partitions
      #  on the first copy are suffixed with ":1") so that we know
      #  the exact size of the rootvg.
      # ########################################################################
      def self.check_rootvg_mirror(vios,
          copies,
          nb_of_pp)
        Log.log_debug('check_rootvg_mirror for vios of ' + vios.to_s)
        # By default we return 0, meaning disk is not mirrored
        ret = 0
        hdisk_copy = {}
        copy_hdisk = {}
        # if not mirrored
        number_of_pp = 0
        # if mirrored
        number_of_pp_1 = 0
        # maxcopy indicates the number of copies
        #  maxcopy=1 meaning only one copy (therefore no mirror)
        #  maxcopy=2 (or above?) meaning more than one copies (therefore mirror)
        maxcopy = 0
        # maxcopy stores the number of copies, if rootvg is not mirrored maxcopy = 1
        #  else maxcopy=2 or maxcopy=3

        # ########################################################################
        # The lsvg -M command lists the physical disks that contain the
        #   various logical volumes.
        # lsvg -M rootvg command OK, check mirroring
        # lists all PV, LV, PP details of a vg (PVname:PPnum LVname: LPnum :Copynum)
        # hdisk4:453      hd1:101
        # hdisk4:454      hd1:102
        # hdisk4:257      hd10opt:1:1
        # hdisk4:258      hd10opt:2:1
        # hdisk4:512-639
        # hdisk8:255      hd1:99:2        stale
        # hdisk8:256      hd1:100:2       stale
        # hdisk8:257      hd10opt:1:2
        # hdisk8:258      hd10opt:2:2
        # ..
        # hdisk9:257      hd10opt:1:3
        # #########################################################################
        remote_cmd1 = "/usr/sbin/lsvg -M rootvg"
        remote_output1 = []
        Log.log_debug('running ' + remote_cmd1 + ' on ' + vios.to_s)
        remote_cmd_rc1 = Remote.c_rsh(vios,
                                      remote_cmd1,
                                      remote_output1)
        #
        if remote_cmd_rc1 == 0
          if !remote_output1[0].nil? and !remote_output1[0].empty?
            #Log.log_debug('remote_output1[0]=' + remote_output1[0].to_s)
            remote_output1_lines = remote_output1[0].split("\n")
            #Log.log_debug('remote_output1_lines=' + remote_output1_lines.to_s)
            remote_output1_lines.each do |remote_output1_line|
              #
              # copy stores the copy on which the pp is located
              #  either 1 if not mirror, or 2 or 3 if mirrored.
              #
              copy = 0
              remote_output1_line.chomp!
              # Log.log_debug('remote_output_lines=' + remote_output1_line.to_s)
              if remote_output1_line.include? 'stale'
                msg = "The \"#{vios}\" rootvg contains stale partitions."
                Log.log_warning(msg)
                Vios.add_vios_journal_msg(vios, msg)
                ret = -1
                break
              elsif remote_output1_line.strip =~ /^(\S+):\d+\s+\S+:\d+:(\d+)\s*$/
                #  case: hdisk8:257 hd10opt:1:1 or hdisk8:257 hd10opt:1:2 or hdisk8:257 hd10opt:1:3
                hdisk = Regexp.last_match(1)
                copy = Regexp.last_match(2).to_i
                if maxcopy < copy
                  maxcopy = copy
                end
                if remote_output1_line.strip =~ /^\S+:\d+\s+\S+:\d+:1\s*$/
                  #  only case: hdisk8:257 hd10opt:1:1
                  number_of_pp_1 += 1
                  copy = 1
                  if maxcopy < copy
                    maxcopy = copy
                  end
                end
              elsif remote_output1_line.strip =~ /^(\S+):\d+\s+\S+:\d+\s*$/
                # case: hdisk8:258 hd10opt:2
                hdisk = Regexp.last_match(1)
                number_of_pp += 1
                number_of_pp_1 += 1
                copy = 1
                if maxcopy < copy
                  maxcopy = copy
                end
              else
                next
              end
              # Log.log_info('hdisk=' + hdisk.to_s + ' copy=' + copy.to_s)
              # Log.log_info('hdisk_copy.key?(hdisk)=' + hdisk_copy.key?(hdisk).to_s)
              if hdisk_copy.key?(hdisk)
                # Log.log_info('hdisk_copy.key?(hdisk)=' + hdisk_copy.key?(hdisk).to_s)
                if hdisk_copy[hdisk] != copy
                  Log.log_info('hdisk_copy[hdisk]=' + hdisk_copy[hdisk].to_s)
                  msg = "The \"#{vios}\" rootvg data structure is not compatible with an \
alt_disk_copy operation (2 copies on the same disk)."
                  Log.log_warning(msg)
                  Vios.add_vios_journal_msg(vios, msg)
                  ret = -1
                end
              else
                hdisk_copy[hdisk] = copy
                # Log.log_debug('check_rootvg_mirror hdisk_copy=' + hdisk_copy.to_s)
                # Log.log_info('!copy_hdisk.key?(copy)=' + (!copy_hdisk.key?(copy)).to_s)
                unless copy_hdisk.key?(copy)
                  # Log.log_info('copy_hdisk.value?(hdisk)=' + copy_hdisk.value?(hdisk).to_s)
                  if copy_hdisk.value?(hdisk)
                    msg = "The \"#{vios}\" rootvg data structure is not compatible with an \
alt_disk_copy operation (one copy spreads on more than one disk)."
                    Log.log_warning(msg)
                    Vios.add_vios_journal_msg(vios, msg)
                    ret = -1
                  else
                    copy_hdisk[copy] = hdisk
                    Log.log_debug('check_rootvg_mirror copy_hdisk=' + copy_hdisk.to_s)
                  end
                end
              end
              #
              if ret == -1
                break
              end
            end # Loop on all lines
            # Log.log_debug('check_rootvg_mirror nb_lp='+nb_lp.to_s)
          end
        else
          ret = -1
        end

        #
        if ret == 0
          if copy_hdisk.keys.length > 1 and (copy_hdisk.keys.length != hdisk_copy.keys.length)
            msg = "The \"#{vios}\" rootvg is partially or completely mirrored but some \
LP copies are spread on several disks. This prevents the \
system from building an altinst_rootvg."
            Log.log_warning(msg)
            Vios.add_vios_journal_msg(vios, msg)
            ret = -1
          else
            if maxcopy > 1
              msg = "The \"#{vios}\" rootvg is partially or completely mirrored \
and its mirroring is compatible with performing an altinst_rootvg.\
Un-mirroring with be done before and mirroring will be redone after."
              Log.log_info(msg)
              Vios.add_vios_journal_msg(vios, msg)
              copies[0] = copy_hdisk
              nb_of_pp[0] = number_of_pp_1
              ret = 1
            else
              msg = "The \"#{vios}\" rootvg is not mirrored, then there is no \
specific constraints before performing an altinst_rootvg."
              Log.log_info(msg)
              Vios.add_vios_journal_msg(vios, msg)
              copies[0] = copy_hdisk
              nb_of_pp[0] = number_of_pp
            end
          end
        end
        #
        Log.log_debug('check_rootvg_mirror for vios of ' + vios.to_s +
                          ' returning (' + copies.to_s + ',' +
                          nb_of_pp.to_s + ') ret=' + ret.to_s)
        ret
      end


      # ##################################################################
      # name : perform_mirror
      # param : in:vios:string
      # param : in:vg_name:string
      # param : out:copies:hash
      # return : 0 if success, 1 if failure, -1 if not done
      # description :
      #  Run NIM mirror command
      # ##################################################################
      def self.perform_mirror(vios,
          vg_name,
          copies)
        Log.log_debug('Performing mirroring of rootvg on "' + vios.to_s + '" vios vg_name=' + vg_name.to_s + ' copies=' + copies.to_s)
        ret = 0
        nb_copies = copies.length
        if nb_copies > 0
          ret = 0
          copy_nb = nb_copies + 1
          Log.log_debug('Performing mirroring of rootvg on ' + vios)
          remote_cmd1 = "/usr/sbin/mirrorvg -m -c #{copy_nb} #{vg_name} #{copies[0]} "
          remote_cmd1 += copies[1] if nb_copies > 1
          remote_cmd1 += ' 2>&1'
          remote_output1 = []
          Log.log_debug('Performing mirroring of rootvg on ' + vios + ':' + remote_cmd1)
          remote_cmd1_rc = Remote.c_rsh(vios, remote_cmd1, remote_output1)
          #
          if remote_cmd1_rc == 0
            Log.log_debug('remote_output1[0] ' + remote_output1[0])
            remote_output1[0].each_line do |remote_output1_line|
              remote_output1_line.chomp!
              Log.log_debug(" #{remote_output1_line}")
              ret = 1 if remote_output1_line.include? 'Failed to mirror the volume group'
            end
          else
            ret = 1
            Log.log_err("[STDERR] #{remote_output1[0]}")
            msg = "Failed to mirror '#{vg_name}' on #{vios}, command \"#{remote_cmd1}\" returns error, (see logs)!"
            Log.log_err(msg)
            Vios.add_vios_journal_msg(vios, msg)
          end
          #
          if ret == 0
            msg = "Mirroring of '#{vg_name}' on '#{vios}' successful."
            Log.log_info(msg)
            Vios.add_vios_journal_msg(vios, msg)
          end
        end
        ret
      end


      # ##################################################################
      # name : perform_unmirror
      # param : in:vios:string
      # param : in:vg_name:string
      # return : ?? 0 if success, 1 if failure, -1 if not done
      # description :
      #  Run NIM unmirror command
      # ##################################################################
      def self.perform_unmirror(vios,
          vg_name)
        Log.log_debug('Performing un-mirroring of rootvg on "' + vios + '" vios vg_name=' + vg_name.to_s)
        ret = 0
        remote_cmd1 = "/usr/sbin/unmirrorvg #{vg_name} 2>&1 "
        remote_output1 = []
        Log.log_debug('Performing un-mirroring of rootvg on ' + vios + ':' + remote_cmd1)
        remote_cmd1_rc = Remote.c_rsh(vios, remote_cmd1, remote_output1)
        #
        if remote_cmd1_rc == 0
          Log.log_debug('remote_output1[0] ' + remote_output1[0].to_s)
          remote_output1[0].each_line do |remote_output1_line|
            remote_output1_line.chomp!
            Log.log_debug(" #{remote_output1_line}")
            ret = 0 if remote_output1_line.include? 'successfully un-mirrored'
          end
        else
          ret = 1
          Log.log_err("[STDERR] #{remote_output1[0]}")
          msg = "Failed to un-mirror '#{vg_name}' on #{vios}, command \"#{remote_cmd1}\" returns error, (see logs)!"
          Log.log_err(msg)
          Vios.add_vios_journal_msg(vios, msg)
        end

        #
        if ret == 0
          msg = "Unmirroring of '#{vg_name}' on '#{vios}' successful."
          Log.log_info(msg)
          Vios.add_vios_journal_msg(vios, msg)
        end
        ret
      end

      # ##################################################################
      # name : check_ssp_cluster
      # param : in:vios_pair:array of two vios [vios1,vios2]
      # param : inout:nim_vios:hashtable
      # description : Check there is or not a SSP cluster and get its
      #   name.
      # returns : cluster name if it is the same on both vios,
      #   empty string otherwise.
      # ##################################################################
      def self.check_ssp_cluster(vios_pair,
          nim_vios)
        Log.log_debug('Checking SSP cluster on ' + vios_pair.to_s + ' vios pair with nim_vios' + nim_vios.to_s)
        cluster_name = ''
        cluster_name_1 = ''
        cluster_name_2 = ''
        # Get the SSP status on both vios of the pair
        vios_pair.each do |vios|
          cluster_name = nim_vios[vios]['SSP_CLUSTER_NAME']
          if cluster_name.nil? or cluster_name.empty?
            msg = "There is no SSP cluster on the \"#{vios}\" vios"
            Log.log_debug(msg)
            Vios.add_vios_journal_msg(vios, msg)
          else
            if cluster_name_1 == ''
              cluster_name_1 = cluster_name
            else
              cluster_name_2 = cluster_name
            end
            msg = "There is one SSP cluster on the \"#{vios}\" vios and its name is \"#{cluster_name}\""
            Log.log_debug(msg)
            Vios.add_vios_journal_msg(vios, msg)
          end
        end
        #
        if cluster_name_1 != cluster_name_2 and cluster_name != ''
          vios_pair.each do |vios|
            msg = 'SSP cluster name is not the same of both vios of the pair'
            Log.log_err(msg)
            Vios.add_vios_journal_msg(vios, msg)
          end
          cluster_name = ''
        end
        cluster_name
      end

      # ##################################################################
      # name : get_vios_ssp_status
      # param : in:vios_pair:array of two vios [vios1,vios2]
      # param : inout:nim_vios:hashtable
      # description : Get the SSP status on each VIOS of the VIOS pair.
      #  As a matter of fact, update IOS can only be performed when both
      #  VIOSes in the tuple refer to the same cluster and have the same
      #  SSP status.
      # returns : 0 if status was got, 1 otherwise
      # # ##################################################################
      def self.get_vios_ssp_status(vios_pair,
          nim_vios)
        Log.log_debug('Getting SSP status on ' + vios_pair.to_s + ' vios pair')
        #
        returned = 0
        vios_ssp_status = {}
        #
        if vios_pair.length >= 1
          vios1 = vios_pair[0]
          nim_vios[vios1]['cluster_ssp_vios_status'] = 'None'
          nim_vios[vios1]['ssp_vios_status'] = {}
        end
        if vios_pair.length >= 2
          vios2 = vios_pair[1]
          nim_vios[vios2]['cluster_ssp_vios_status'] = 'None'
          nim_vios[vios2]['ssp_vios_status'] = {}
        end

        # Get the SSP status on both vios of the pair
        vios_pair.each do |vios|
          remote_cmd1 = "/usr/ios/cli/ioscli cluster -list && /usr/ios/cli/ioscli cluster -status -fmt :"
          remote_output1 = []
          Log.log_debug('Check SSP VIOS cluster ' + vios.to_s)
          remote_cmd_rc1 = Remote.c_rsh(vios,
                                        remote_cmd1,
                                        remote_output1)
          #
          Log.log_debug("remote_output1[0]=" + remote_output1[0].to_s + ' remote_cmd_rc1=' + remote_cmd_rc1.to_s)
          if !remote_output1[0].nil? and !remote_output1[0].empty?
            # check that the VIOSes belong to the same cluster and have the same satus
            #                  or there is no SSP
            # stdout is like:
            # gdr_ssp3:OK:castor_gdr_vios3:8284-22A0221FD4BV:17:OK:OK
            # gdr_ssp3:OK:castor_gdr_vios2:8284-22A0221FD4BV:16:OK:OK
            #  or
            # Cluster does not exist.
            #
            # Log.log_debug('remote_output1[0]=' + remote_output1[0].to_s)
            remote_output1_lines = remote_output1[0].split("\n")
            # Log.log_debug('remote_output1_lines=' + remote_output1_lines.to_s)
            # vios_ssp_status_vios stores result of the two vios as seen from on of the two vios
            vios_ssp_status_vios = {}
            remote_output1_lines.each do |remote_output1_line|
              remote_output1_line.chomp!
              Log.log_debug("remote_output1_line=" + remote_output1_line.to_s)
              if remote_output1_line =~ /^Cluster does not exist.$/
                nim_vios[vios]['cluster_ssp_vios_status'] = "DOWN"
                msg = "SSP cluster on the \"#{vios}\" vios is DOWN"
                Log.log_debug(msg)
                Vios.add_vios_journal_msg(vios, msg)
              else
                nim_vios[vios]['cluster_ssp_vios_status'] = "UP"
                if remote_output1_line =~ /^(\S+):(\S+):(\S+):\S+:\S+:(\S+):.*/
                  cur_ssp_name = Regexp.last_match(1)
                  cur_ssp_status = Regexp.last_match(2)
                  cur_vios_name = Regexp.last_match(3)
                  cur_vios_ssp_status = Regexp.last_match(4)
                  Log.log_debug(' cur_ssp_name=' + cur_ssp_name.to_s +
                                    ' cur_ssp_status=' + cur_ssp_status.to_s +
                                    ' cur_vios_name=' + cur_vios_name.to_s +
                                    ' cur_vios_ssp_status=' + cur_vios_ssp_status.to_s)
                  vios_ssp_status_vios[cur_vios_name] = []
                  vios_ssp_status_vios[cur_vios_name].push(cur_ssp_name)
                  vios_ssp_status_vios[cur_vios_name].push(cur_ssp_status)
                  vios_ssp_status_vios[cur_vios_name].push(cur_vios_ssp_status)
                end
              end
            end
            vios_ssp_status[vios] = vios_ssp_status_vios
            nim_vios[vios]['ssp_vios_status'] = vios_ssp_status_vios
            msg = "SSP status of \" #{vios} \" vios: ssp_vios_status=#{nim_vios[vios]['ssp_vios_status']} \"
and cluster_ssp_vios_status=#{nim_vios[vios]['cluster_ssp_vios_status']}"
            Vios.add_vios_journal_msg(vios, msg)
            Log.log_info(msg)
          else
            msg = "Failed to get SSP status of #{vios}"
            Log.log_err(msg)
            Log.log_err(remote_output1[0])
            Vios.add_vios_journal_msg(vios, msg)
            returned = 1
          end
        end

        #
        # Log.log_debug('vios_ssp_status[' + vios1 + ']=' + vios_ssp_status[vios1].to_s)
        # Log.log_debug('vios_ssp_status[' + vios2 + ']=' + vios_ssp_status[vios2].to_s)
        # We compare ssp status of two vios as seen from two vios
        #  Each vios has two vios results
        # Log.log_debug((vios_ssp_status[vios1] == vios_ssp_status[vios2]).to_s)

        Log.log_debug('Getting SSP status on ' + vios_pair.to_s + ' vios pair returning ' + returned.to_s)
        returned
      end


      # ##################################################################
      # name : check_vios_ssp_status
      # param : in:vios_pair:array of two vios [vios1,vios2]
      # param : inout:nim_vios:hashtable containing result of
      #   get_vios_ssp_status
      # description : Check the SSP status on each VIOS of the VIOS pair.
      #  As a matter of fact, update IOS can only be performed when both
      #  VIOSes in the tuple refer to the same cluster and have the same
      #  SSP status.
      # returns : true if OK, false otherwise
      # # ##################################################################
      def self.check_vios_ssp_status(vios_pair,
          nim_vios)
        Log.log_debug('Checking SSP status on ' + vios_pair.to_s + ' vios pair') #, with nim_vios='+ nim_vios.to_s)
        #
        ssp_cluster_check = false

        vios1 = ''
        cluster_ssp_vios_status1 = ''
        ssp_vios_status1 = {}
        vios2 = ''
        cluster_ssp_vios_status2 = ''
        ssp_vios_status2 = {}
        #
        if vios_pair.length >= 1
          vios1 = vios_pair[0]
        end
        if vios_pair.length >= 2
          vios2 = vios_pair[1]
        end

        if vios_pair.length >= 1
          #
          # cluster_ssp_vios_status1_ = nim_vios[vios1]
          # Log.log_debug('cluster_ssp_vios_status1_=' + cluster_ssp_vios_status1_.to_s)
          #
          cluster_ssp_vios_status1 = nim_vios[vios1]['cluster_ssp_vios_status']
          # Log.log_debug('cluster_ssp_vios_status1=' + cluster_ssp_vios_status1.to_s)
          #
          ssp_vios_status1 = nim_vios[vios1]['ssp_vios_status']
          # Log.log_debug('ssp_vios_status1=' + ssp_vios_status1.to_s)
        end

        if vios_pair.length >= 2
          # cluster_ssp_vios_status2_ = nim_vios[vios2]
          # Log.log_debug('cluster_ssp_vios_status2_=' + cluster_ssp_vios_status2_.to_s)
          #
          cluster_ssp_vios_status2 = nim_vios[vios2]['cluster_ssp_vios_status']
          # Log.log_debug('cluster_ssp_vios_status2=' + cluster_ssp_vios_status2.to_s)
          #
          ssp_vios_status2 = nim_vios[vios2]['ssp_vios_status']
          # Log.log_debug('ssp_vios_status2=' + ssp_vios_status2.to_s)
          #
        end

        # If both vios have a SSP cluster, then they must have the same output
        # We compare ssp status of two vios as seen from two vios
        #  Each vios has two vios results
        if vios_pair.length == 2
          # Log.log_debug((cluster_ssp_vios_status1 == cluster_ssp_vios_status2).to_s)
          # Log.log_debug((ssp_vios_status1 == ssp_vios_status2).to_s)
          if cluster_ssp_vios_status1 == cluster_ssp_vios_status2 and
              ssp_vios_status1 == ssp_vios_status2
            ssp_cluster_check = true
          else
            ssp_cluster_check = false
          end
        elsif vios_pair.length == 1
          ssp_cluster_check = true
        end
        #
        unless ssp_cluster_check
          msg = "Checking SSP status on #{vios_pair} vios pair returning #{ssp_cluster_check}: \
therefore it is not possible to continue VIOS update on this pair."
          Vios.add_vios_journal_msg(vios1, msg)
          Vios.add_vios_journal_msg(vios2, msg)
          Log.log_debug(msg)
        end

        ssp_cluster_check
      end


      # ##################################################################
      # name : ssp_stop_start
      # param : in:action:string
      # param : in:vios:string
      # param : in:vios_pair:array
      # param : inout:nim_vios:hashtable
      # description : Stop or start the SSP for a VIOS
      #
      #   If you don't stop SSP cluster before performing update, you risk :
      #    0042-001 nim: processing error encountered on "master":
      #    0042-001 m_updateios: processing error encountered on "p7juav2":
      #    The requested operation is not allowed because partition is
      #     a member of "p7juaclu" cluster.
      #
      # returns : true if OK, false otherwise
      # ##################################################################
      def self.ssp_stop_start(action,
          vios_to_action,
          vios_pair,
          nim_vios)
        Log.log_info('Performing "' + action.to_s + '" SSP action on "' + vios_to_action.to_s + '" vios')
        #
        returned = false
        perform_action = false
        # we need to start vios_to_action from other_vios
        other_vios = ''
        ssp_name = ''
        #
        vios_pair.each do |vios|
          ssp_name = nim_vios[vios]['SSP_CLUSTER_NAME']
          cluster_ssp_vios_status = nim_vios[vios]['cluster_ssp_vios_status']
          Log.log_debug('cluster_ssp_vios_status (as seen from ' + vios.to_s + ') of ' + ssp_name.to_s + ' cluster=' + cluster_ssp_vios_status.to_s)
          #
          if cluster_ssp_vios_status == 'DOWN' and action == 'start'
            perform_action = true
          elsif cluster_ssp_vios_status == 'UP' and action == 'stop'
            perform_action = true
          end
          if vios != vios_to_action
            other_vios = vios
          end
        end

        # If ever both SSP node were DOWN ate the beginning, not needed to restart
        if action == 'start' and nim_vios[other_vios]['cluster_ssp_vios_status'] == 'DOWN'
          perform_action = false
        end

        if perform_action
          #
          vios_to_c_rsh = ''
          if action == 'start'
            vios_to_c_rsh = other_vios
          else
            vios_to_c_rsh = vios_to_action
          end
          #
          remote_cmd1 = "PATH=$PATH:/usr/bin /usr/sbin/clctrl -#{action} -n #{ssp_name} -m #{vios_to_action}"
          remote_output1 = []
          Log.log_debug('Launching SSP action ' + action.to_s +
                            ' on ' + vios_to_action.to_s +
                            ' from to ' + vios_to_c_rsh.to_s + ' vios.')
          remote_cmd_rc1 = Remote.c_rsh2(vios_to_c_rsh,
                                         remote_cmd1,
                                         remote_output1)
          #
          if remote_cmd_rc1 == 0
            if !remote_output1[0].nil? and !remote_output1[0].empty?
              remote_output1_lines = remote_output1[0].split("\n")
              # Log.log_debug('remote_output1_lines=' + remote_output1_lines.to_s)
              remote_output1_lines.each do |remote_output1_line|
                remote_output1_line.chomp!
                Log.log_debug('remote_output1_line=' + remote_output1_line.to_s)
              end
              nim_vios[vios_to_action]['cluster_ssp_vios_status'] = if action == 'stop'
                                                                      "DOWN"
                                                                    else
                                                                      "UP"
                                                                    end
              msg = "Cluster #{nim_vios[vios_to_action]['SSP_CLUSTER_NAME']} #{action} on '#{vios_to_action}' vios succeeded."
              Log.log_info(msg)
              Vios.add_vios_journal_msg(vios_to_action, msg)
              returned = true
            else
              if action == 'stop'
                nim_vios[vios_to_action]['cluster_ssp_vios_status'] = "DOWN"
              else
                nim_vios[vios_to_action]['cluster_ssp_vios_status'] = "UP"
              end
              msg = "Cluster #{nim_vios[vios_to_action]['SSP_CLUSTER_NAME']} #{action} on '#{vios_to_action}' vios succeeded."
              Log.log_info(msg)
              Vios.add_vios_journal_msg(vios_to_action, msg)
              returned = true
            end
          else
            # Try to dump output to understand why it failed
            if !remote_output1[0].nil? and !remote_output1[0].empty?
              remote_output1_lines = remote_output1[0].split("\n")
              remote_output1_lines.each do |remote_output1_line|
                remote_output1_line.chomp!
                Log.log_err('ERROR SSP START:' + remote_output1_line.to_s)
              end
            end
            msg = "Failed to #{action} '#{nim_vios[vios_to_action]['SSP_CLUSTER_NAME']}' cluster on '#{vios_to_action}' vios"
            Log.log_err(msg)
            Vios.add_vios_journal_msg(vios_to_action, msg)
            returned = false
          end
        else
          msg = "Nothing to be done, as far as SSP is concerned, on '#{vios_to_action}' vios."
          Log.log_debug(msg)
          Vios.add_vios_journal_msg(vios_to_action, msg)
          returned = true
        end
        returned
      end


      # ##################################################################
      # name : prepare_updateios_command
      # param : in:lpp_source:string
      # param : in:options:array of strings
      # param : in:update_options:string
      # return : the command string to pass to nim_updateios()
      # description :
      #  Builds the NIM updateios command to run
      # ##################################################################
      def self.prepare_updateios_command(vios,
          lpp_source,
          options,
          update_options)
        Log.log_debug('prepare_updateios_command vios=' + vios.to_s +
                          ' lpp_source=' + lpp_source +
                          ' options=' + options.to_s +
                          ' update_options=' + update_options.to_s)
        cmd = '/usr/sbin/nim -o updateios'

        # lpp_source
        if !lpp_source.nil? && !lpp_source.empty?
          cmd << " -a lpp_source=#{lpp_source}"
        end

        # options
        if !options.nil? && !options.empty?
          # accept licenses
          cmd << if options.include? 'accept_licenses'
                   ' -a accept_licenses=yes'
                 else
                   ' -a accept_licenses=no'
                 end
          cmd << if options.include? 'preview'
                   ' -a preview=yes'
                 else
                   ' -a preview=no'
                 end
        else
          cmd << ' -a accept_licenses=no -a preview=no'
        end

        # update_options
        if !update_options.nil? && !update_options.empty?
          # preview mode
          if update_options == 'commit' or update_options == 'install' or
              update_options == 'remove' or update_options == 'reject' or
              update_options == 'cleanup'
            cmd << ' -a updateios_flags=-' + update_options.to_s
          end
        end

        cmd << " #{vios}"

        updateios_output_file = Vios.get_updateios_output_file_name(vios)

        cmd << '> ' + updateios_output_file + ' 2>&1'

        msg = 'Preparing update command for "' + vios.to_s + '" vios successful: "' + cmd.to_s + '"'
        Log.log_info(msg)
        Vios.add_vios_journal_msg(vios, msg)

        cmd
      end


      # ##################################################################
      # name : vios_levels
      # param : in:step:string Either 'Before' or 'After'
      # param : in:vios:string
      # return : nothing
      # description :
      #  Log oslevel and ioslevel of vios
      # ##################################################################
      def self.vios_levels(step,
          vios)
        Log.log_debug('vios_levels step="' + step.to_s +
                          '" vios="' + vios.to_s + '"')
        oslevel = ''
        ioslevel = ''
        remote_cmd_rc = Remote.c_rsh(vios, '/usr/bin/oslevel -s', oslevel)
        if remote_cmd_rc == 0
          oslevel = oslevel.strip
        end

        remote_cmd_rc = Remote.c_rsh(vios, '/usr/ios/cli/ioscli ioslevel', ioslevel)
        if remote_cmd_rc == 0
          ioslevel = ioslevel.strip
        end

        msg = step.to_s + ' NIM updateios operation of ' + vios.to_s +
            ' oslevel=' + oslevel.to_s +
            ' ioslevel=' + ioslevel.to_s
        Log.log_info(msg)
        Vios.add_vios_journal_msg(vios, msg)
      end

      # ##################################################################
      # name : nim_updateios
      # param : in:cmd:string
      # param : in:vios:string
      # param : in:step:string either update or autocommit
      # return : 0 if success 1 otherwise
      # description :
      #  Run the NIM updateios operation on specified vios
      #  The command to run is built by prepare_updateios_command()
      # ##################################################################
      def self.nim_updateios(cmd,
          vios,
          step)
        Log.log_debug('nim_updateios cmd="' + cmd +
                          '" vios="' + vios + '"')
        msg_step = 'vios ' + step
        msg = msg_step + ' of "' + vios.to_s + '" vios with NIM updateios command: "' + cmd.to_s + '"'
        Log.log_info(msg)
        Vios.add_vios_journal_msg(vios, msg.to_s)

        ret = 0
        Vios.vios_levels('Before ' + msg_step, vios)

        # stdout and stderr are redirected to updateios_output_file
        Open3.popen3({'LANG' => 'C'}, cmd) do |_stdin, _stdout, _stderr, wait_thr|
          #
          updateios_output_file = Vios.get_updateios_output_file_name(vios, step)
          Log.log_info('Refer to ' + updateios_output_file.to_s + ' to see output of ' + cmd.to_s)

          #
          if wait_thr.value.success?
            if cmd.include? 'preview=yes'
              msg = 'NIM updateios operation of ' + vios.to_s + ' successful, update was done in preview only.'
            else
              msg = 'NIM updateios operation of ' + vios.to_s + ' successful, and update is committed.'
            end
            Log.log_info(msg)
            Vios.add_vios_journal_msg(vios, msg)
          else
            if cmd.include? 'preview=yes'
              Log.log_info('Preview always returns error (by nature), this error code can be considered as normal')
              ret = 0
            else
              ret = 1
            end
            Log.log_info('step=' + step.to_s)
            if step == 'autocommit'
              cmd2 = '/bin/grep "There are no uncommitted updates" ' + updateios_output_file
              Log.log_debug('cmd2=' + cmd2.to_s)
              Open3.popen3({'LANG' => 'C'}, cmd2) do |_stdin2, _stdout2, _stderr2, wait_thr2|
                Log.log_debug('wait_thr2.value=' + wait_thr2.value.to_s)
                if wait_thr2.value.success?
                  ret = 0
                end
              end
            elsif step == 'update'
              cmd2 = '/bin/grep -p STATISTICS ' + updateios_output_file
              Log.log_debug('cmd2=' + cmd2.to_s)
              Open3.popen3({'LANG' => 'C'}, cmd2) do |_stdin2, stdout2, stderr2, wait_thr2|
                Log.log_debug('wait_thr2.value=' + wait_thr2.value.to_s)
                stdout2.each_line do |line|
                  if line =~ /\s+0\s+Total to be installed/
                    ret = 0
                  end
                  if !line.nil? and !line.empty?
                    Log.log_debug(" #{line.chomp}")
                    Vios.add_vios_journal_msg(vios, line.chomp)
                  end
                end
                stderr2.each_line do |line|
                  Log.log_err("[STDERR] #{line.chomp}")
                end
                Log.log_debug('cmd2 ' + cmd2.to_s + ' returns ' + ret.to_s)
                # Process::Status object returned.
              end
              #
              cmd3 = '/bin/grep -p "Installation Summary" ' + updateios_output_file
              Log.log_debug('cmd3=' + cmd3.to_s)
              Open3.popen3({'LANG' => 'C'}, cmd3) do |_stdin3, stdout3, stderr3, _wait_thr3|
                ## Log.log_info('wait_thr3.value=' + wait_thr3.value.to_s)
                stdout3.each_line do |line|
                  if !line.nil? and !line.empty?
                    Log.log_debug(" #{line.chomp}")
                    Vios.add_vios_journal_msg(vios, line.chomp)
                  end
                end
                stderr3.each_line do |line|
                  Log.log_err("[STDERR] #{line.chomp}")
                end
                # Process::Status object returned.
              end

            end
            if ret == 1
              msg = 'Bad return code from NIM updateios ' + step + ' operation on ' + vios.to_s + '" vios, refer to "' + updateios_output_file + '" log file and advise (in some cases, it could be successfull anyway).'
              Log.log_err(msg)
              Vios.add_vios_journal_msg(vios, msg)
            else
              msg = 'NIM updateios ' + step + ' operation on "' + vios.to_s + '" vios succeeded, verify in "' + updateios_output_file + '" log file.'
              Log.log_info(msg)
              Vios.add_vios_journal_msg(vios, msg)
            end
          end
        end
        Vios.vios_levels('After ' + msg_step, vios)
        ret
      end


      # ############################
      #     E X C E P T I O N      #
      # ############################
      class ViosError < StandardError
      end
      #
      class ViosHealthCheckError < ViosError
      end
      #
      class ViosHealthCheckError1 < ViosError
      end
      #
      class ViosHealthCheckError2 < ViosError
      end
      #
      class ViosHealthCheckError3 < ViosError
      end
      #
      class NimHmcInfoError < StandardError
      end
    end
  end
end
