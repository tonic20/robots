require "open-uri"
require "uri"
require "rubygems"
require "timeout"

class Robots
  
  DEFAULT_TIMEOUT = 3
  
  class ParsedRobots
    
    def initialize(uri, user_agent, options = {})
      @last_accessed = Time.at(1)
      
      io = Robots.get_robots_txt(uri, user_agent)
      
      if !io || io.content_type != "text/plain" || io.status.map{|s| s.strip.upcase} != ["200", "OK"]
        io = StringIO.new("User-agent: *\nAllow: /\n")
      end

      @options = options
      @other = {}
      @disallows = {}
      @allows = {}
      @delays = {}
      @clean_params = {}

      agent = /.*/
      io.each do |line|
        next if line =~ /^\s*(#.*|$)/
        arr = line.split(":")
        key = arr.shift.downcase
        value = arr.join(":").strip
        value.strip!
        case key
        when "user-agent"
          agent = to_regex(value)
        when "allow"
          @allows[agent] ||= []
          @allows[agent] << to_regex(value)
        when "disallow"
          @disallows[agent] ||= []
          @disallows[agent] << to_regex(value)
        when "crawl-delay"
          @delays[agent] = value.to_f rescue 0
        when "clean-param"
          @clean_params[agent] ||= []
          @clean_params[agent] << parse_clean_param(value)
        else
          @other[key] ||= []
          @other[key] << value
        end
      end
      
      @parsed = true
    end
    
    def allowed?(uri, user_agent)
      return true unless @parsed
      allowed = true
      path = uri.request_uri
      
      @disallows.each do |key, value|
        if user_agent =~ key
          value.each do |rule|
            if path =~ rule
              allowed = false
            end
          end
        end
      end
      
      @allows.each do |key, value|
        unless allowed      
          if user_agent =~ key
            value.each do |rule|
              if path =~ rule
                allowed = true
              end
            end
          end
        end
      end
      
      if allowed && !@options[:skip_delay]
        delay = crawl_delay(uri, user_agent) - (Time.now - @last_accessed)
        sleep(delay) if delay > 0
        @last_accessed = Time.now
      end
      
      return allowed
    end
    
    def crawl_delay(uri, user_agent)
      return 0 unless @parsed
      delay = 0
      @delays.each { |key, value| delay = value if user_agent =~ key }
      delay
    end

    def clean_url(uri, user_agent)
      url = uri.dup
      return url unless @parsed && url.query
      
      @clean_params.each do |key, value|
        if user_agent =~ key
          value.each do |rule|
            if url.path =~ rule[:path]
              rule[:params].each do |param|
                url.query = url.query.split("&").reject{|p| p =~ /^#{param}=|^#{param}$/}.join("&")
              end
            end
          end
        end
      end
      url.query = nil if url.query.empty?
      url
    end

    def other_values
      @other
    end
    
  protected
    
    def to_regex(pattern)
      return /should-not-match-anything-123456789/ if pattern.strip.empty?
      pattern = Regexp.escape(pattern)
      pattern.gsub!(Regexp.escape("*"), ".*")
      Regexp.compile("^#{pattern}")
    end

    def parse_clean_param(value)
      params, path = value.split
      params = params.split("&")
      { params: params, path: to_regex(path) }
    end
  end
  
  def self.get_robots_txt(uri, user_agent)
    begin
      Timeout::timeout(Robots.timeout) do
        io = URI.join(uri.to_s, "/robots.txt").open("User-Agent" => user_agent) rescue nil
      end 
    rescue Timeout::Error
      STDERR.puts "robots.txt request timed out"
    end
  end
  
  def self.timeout=(t)
    @timeout = t
  end
  
  def self.timeout
    @timeout || DEFAULT_TIMEOUT
  end
  
  def initialize(user_agent, options = {})
    @user_agent = user_agent
    @options = options
    @parsed = {}
  end
  
  def allowed?(uri)
    uri, host = Robots.get_uri_and_host(uri)
    @parsed[host] ||= ParsedRobots.new(uri, @user_agent, @options)
    @parsed[host].allowed?(uri, @user_agent)
  end

  def crawl_delay(uri)
    uri, host = Robots.get_uri_and_host(uri)
    @parsed[host] ||= ParsedRobots.new(uri, @user_agent, @options)
    @parsed[host].crawl_delay(uri, @user_agent)
  end
  
  def clean_url(uri)
    uri, host = Robots.get_uri_and_host(uri)
    @parsed[host] ||= ParsedRobots.new(uri, @user_agent, @options)
    @parsed[host].clean_url(uri, @user_agent)
  end

  def other_values(uri)
    uri, host = Robots.get_uri_and_host(uri)
    @parsed[host] ||= ParsedRobots.new(uri, @user_agent, @options)
    @parsed[host].other_values
  end

  protected

  def self.get_uri_and_host(uri)
    uri = URI.parse(uri.to_s) unless uri.is_a?(URI)
    host = uri.host
    [uri, host]
  end
end