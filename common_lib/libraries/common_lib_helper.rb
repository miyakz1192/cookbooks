module IniFileLib
  class IniFileDriver

    attr_accessor :filename

    def initialize(filename)
      @filename = filename
    end

    def read(section, param)
      `crudini --get #{@filename} #{section} #{param}`.chomp
    end

    def write(section, param ,value)
      `crudini --set #{@filename} #{section} #{param} #{value}`
    end
  end

  class IniFileContext
    attr_accessor :section_name, :filename, :action
    def initialize(filename, action)
      @filename = filename
      @action = action
      @inifile = IniFileDriver.new(filename)
    end

    def section(name, &block)
      @section_name = name
      block.call self
    end

    def eq(param, expected_value)
      if @action == :check
        real_value = @inifile.read(@section_name, param)
        real_value = real_value.to_s
        expected_value = expected_value.to_s
        unless real_value == expected_value
          raise RecordMismatchException.new(@inifile,
                                            param,
                                            expected_value,
                                            real_value)
        end
      end
    end
  end

  class RecordMismatchException < StandardError
    def initialize(inifile, param, expected_value, real_value)
      @message = "record mismatch param=#{param.inspect} expected value = #{expected_value}, real value = #{real_value.inspect} in #{inifile.filename}"
    end
  
    def message
      @message
    end
  end
end

module IniFileHelper
  include IniFileLib

  def inifile(action_param, &block)
    ctx = IniFileContext.new(@path, action_param[:action])
    filename = filename_for_attr(ctx)
    begin
      node.set[:config_file_check][filename] = "ok"
      block.call ctx
    rescue RecordMismatchException => e
      Chef::Log.error("RecordMismatchException #{e.message}")
      node.set[:config_file_check][filename] = e.message
    end
  end
  
  def filename_for_attr(context)
    return File.basename(context.filename).gsub(/\./,"_").to_sym
  end
end
