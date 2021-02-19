module FilesHelper

  def prune_tmp_folder
    Pathname.new(tmp_folder).children.each do |p|
      begin
        p.unlink
      rescue
        begin
          FileUtils.rm_rf(p.to_s)
        rescue
        end
      end
    end
  end

  def stage_out_data_file(short_name:)
    tmp_path = make_tmp_path(short_name: short_name)
    FileUtils.cp(locate_data_file(short_name: short_name), tmp_path)
    tmp_path
  end

  def make_tmp_path(short_name: "#{SecureRandom.hex(10)}.tmp")
    File.join(tmp_folder, short_name)
  end

  def locate_data_file(short_name:)
    File.join(data_folder, short_name)
  end

  def tmp_folder
    retval = File.expand_path(File.join(File.dirname(__FILE__), '../../tmp'))
    FileUtils.mkdir_p(retval)
    retval
  end

  def data_folder
    File.expand_path(File.join(
      File.dirname(__FILE__), 'data'))
  end

end
