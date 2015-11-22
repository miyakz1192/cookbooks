module IniFileLib
  class IniFileDriver

    attr_accessor :filename

    def initialize(filename)
      @filename = filename
    end

    def read(section, param)
      `crudini --get #{@filename} #{section} #{param}`.chomp
    end

    def read_sections
      `crudini --get --list #{@filename}`.split("\n")
    end

    def read_params_in_section(section)
      `crudini --get --list #{@filename} #{section}`.split("\n")
    end

    def write(section, param ,value)
      `crudini --set #{@filename} #{section} #{param} #{value}`
    end

    # hash key is section name
    # hash value is params in section
    def all_params
      res = {}
      read_sections.each do |section|
        res[section] = read_params_in_section(section)
      end
      return res
    end
  end

  class IniFileContext
    attr_accessor :filename, :errors, :unchecked_params

    def initialize(filename, action)
      @filename = filename
      @action = action
      @inifile = IniFileDriver.new(filename)
      @errors = [] #error string array
      @section_name = nil
      @unchecked_params = @inifile.all_params
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

    def has_unchecked_params?
      @unchecked_params.each_key do |k|
        return true if @unchecked_params[k].size > 0
      end
      return false
    end

    def num_of_unchecked_params
      num = 0
      @unchecked_params.each_key do |k|
        num += @unchecked_params[k].size
      end
      return num
    end

    protected
    def check(param, expected_value)
      real_value = @inifile.read(@section_name, param).to_s
      expected_value = expected_value.to_s
      unless real_value == expected_value
        @errors << "record mismatch param=#{param.inspect} expected value = #{expected_value}, real value = #{real_value.inspect} in #{@inifile.filename}"
      end
      @unchecked_params[@section_name].delete(param)
    end

    def fix(param, expected_value)
      @inifile.write(@section_name, param, expected_value)
      @unchecked_params[@section_name].delete(param)
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

    node.set[:config_file_check] = {}
    node.set[:config_file_check][filename] = {}

    check_result = []
    begin
      block.call ctx
    rescue => e
      Chef::Log.error("Unexpected #{e.message}")
      check_result = [e.message]
    end

    if ctx.has_some_errors?
      check_result << ctx.errors
      Chef::Log.error(ctx.errors)
    else
      check_result = "ok"
    end

    Chef::Log.info("miyakz100 = #{filename}")
    node.set[:config_file_check][filename][:check_result] = check_result

    unchecked_res = []
    if ctx.has_unchecked_params?
      node.set[:config_file_check][filename][:num_of_unchecked_params] = ctx.num_of_unchecked_params
      unchecked_res = ctx.unchecked_params
    else
      unchecked_res = "ok"
    end
    node.set[:config_file_check][filename][:unchecked_params] = unchecked_res
  end
  
  def filename_for_attr(context)
    return File.basename(context.filename).gsub(/\./,"_").to_sym
  end
end
