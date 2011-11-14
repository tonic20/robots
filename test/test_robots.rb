#!/usr/bin/env ruby
require "test/unit"
require File.dirname(__FILE__) + "/../lib/robots"

module FakeHttp
  def content_type
    "text/plain"
  end
  
  def status
    ["200", "OK"]
  end
end

class TestRobots < Test::Unit::TestCase
  def setup
    def Robots.get_robots_txt(uri, user_agent)
      fixture_file = File.dirname(__FILE__) + "/fixtures/" + uri.host.split(".")[-2] + ".txt"
      File.open(fixture_file).extend(FakeHttp)
    end
    
    @robots = Robots.new "Ruby-Robot.txt Parser Test Script"
    @robots_mobot = Robots.new "Mobot"
  end
  
  def test_allowed_if_no_robots
    def Robots.get_robots_txt(uri, user_agent)
      return nil
    end
    
    assert_allowed("somesite", "/")
  end
  
  def test_disallow_nothing
    assert_allowed("emptyish", "/")
    assert_allowed("emptyish", "/foo")
  end
  
  def test_reddit
    assert_allowed("reddit", "/")
  end
  
  def test_other
    assert_allowed("yelp", "/foo")
    assert_disallowed("yelp", "/mail?foo=bar")
  end
  
  def test_site_with_disallowed
    assert_allowed("google", "/")
  end
  
  def test_other_values
    sitemap = {"sitemap" => ["http://www.eventbrite.com/sitemap_index.xml", "http://www.eventbrite.com/sitemap_index.xml"]}
    assert_other_equals("eventbrite", sitemap)
  end

  def test_crawl_delay
    assert_equal(1, @robots.crawl_delay(uri_for_name("extended", "/")))
    assert_equal(0.5, @robots_mobot.crawl_delay(uri_for_name("extended", "/")))
  end

  def test_clean_url
    h = uri_for_name("extended")
    assert_equal("#{h}/", @robots.clean_url("#{h}/").to_s)
    assert_equal("#{h}/test", @robots.clean_url("#{h}/test").to_s)

    assert_equal("#{h}/", @robots.clean_url("#{h}/?term1=test").to_s)
    assert_equal("#{h}/?tt=qq", @robots.clean_url("#{h}/?term1=test&tt=qq").to_s)
    assert_equal("#{h}/?tt=qq", @robots.clean_url("#{h}/?tt=qq&term1=test&term1=test2").to_s)
    assert_equal("#{h}/aaa/zzz", @robots.clean_url("#{h}/aaa/zzz?term1=test").to_s)
    assert_equal("#{h}/path1/", @robots.clean_url("#{h}/path1/?term2=test").to_s)

    assert_equal("#{h}/", @robots_mobot.clean_url("#{h}/?term1=test").to_s)
    assert_equal("#{h}/?tt=qq", @robots_mobot.clean_url("#{h}/?term1=test&tt=qq").to_s)
    assert_equal("#{h}/?tt=qq", @robots_mobot.clean_url("#{h}/?tt=qq&term1=test&term1=test2").to_s)
    assert_equal("#{h}/aaa/zzz", @robots_mobot.clean_url("#{h}/aaa/zzz?term1=test").to_s)
    assert_equal("#{h}/path1", @robots_mobot.clean_url("#{h}/path1?term2=test").to_s)

    assert_equal("#{h}/", @robots_mobot.clean_url("#{h}/?term5=test").to_s)
    assert_equal("#{h}/?term3=test&term4=test", @robots_mobot.clean_url("#{h}/?term3=test&term4=test").to_s)
    assert_equal("#{h}/path2", @robots_mobot.clean_url("#{h}/path2?term3=test&term4=test").to_s)

    assert_equal("#{h}/forum_old/showthread.php?t=8243", @robots.clean_url("#{h}/forum_old/showthread.php?s=681498605&t=8243&ref=1311").to_s)

    h = uri_for_name("emptyish")
    assert_equal("#{h}/qwerty?t=asd", @robots.clean_url("#{h}/qwerty?t=asd").to_s)
  end
  
  def assert_other_equals(name, value)
    assert_equal(value, @robots.other_values(uri_for_name(name, "/")))
  end
  
  def assert_allowed(name, path)
    assert_allowed_equals(name, path, true)
  end
  
  def assert_disallowed(name, path)
    assert_allowed_equals(name, path, false)
  end
  
  def assert_allowed_equals(name, path, value)
    assert_equal(value, @robots.allowed?(uri_for_name(name, path)), @robots.inspect)
  end
  
  def uri_for_name(name, path=nil)
    uri = name.nil? ? nil : "http://www.#{name}.com#{path}"
  end 
end