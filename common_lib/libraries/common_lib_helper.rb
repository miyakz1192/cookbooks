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
    attr_accessor :section_name, :filename, :action, :errors
    def initialize(filename, action)
      @filename = filename
      @action = action
      @inifile = IniFileDriver.new(filename)
      @errors = [] #error string array
    end

    def section(name, &block)
      @section_name = name
      block.call self
    end

    def eq(param, expected_value)
      case @action
      when :check
        check(param, expected_value)
      when :fix
        fix(param, expected_value)
      else
        raise "no such action #{@action}"
      end
    end

    def has_some_errors?
      @errors.size > 0
    end

    protected
    def check(param, expected_value)
      real_value = @inifile.read(@section_name, param).to_s
      expected_value = expected_value.to_s
      unless real_value == expected_value
        @errors << "record mismatch param=#{param.inspect} expected value = #{expected_value}, real value = #{real_value.inspect} in #{@inifile.filename}"
      end
    end

    def fix(param, expected_value)
      @inifile.write(@section_name, param, expected_value)
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
      node.set[:config_file_check][filename] = []
      block.call ctx
    rescue => e
      Chef::Log.error("Unexpected #{e.message}")
      node.set[:config_file_check][filename] = [e.message]
    end
    if ctx.has_some_errors?
      node.set[:config_file_check][filename] << ctx.errors
      Chef::Log.error(ctx.errors)
    else
      node.set[:config_file_check][filename] = "ok"
    end
  end
  
  def filename_for_attr(context)
    return File.basename(context.filename).gsub(/\./,"_").to_sym
  end
end
