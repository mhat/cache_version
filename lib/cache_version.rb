require 'rubygems'
require 'active_record'
require 'memcache_extended'

module CacheVersion
  def self.db
    ActiveRecord::Base.connection
  end
  
  def self.cache
    CACHE
  end

  def self.get(key)
    key = key.to_s
    version_by_key[key] ||= CACHE.get_or_set(cache_key(key)) do
      db.select_value("SELECT version FROM cache_versions WHERE key = '#{key}'").to_i
    end
  end

  def self.increment(key)
    key = key.to_s
    if get(key) == 0
      db.execute("INSERT INTO cache_versions (key, version) VALUES ('#{key}', 1)")
    else
      db.execute("UPDATE cache_versions SET version = version + 1 WHERE key = '#{key}'")
    end
    invalidate_cache(key)
  end

  def self.invalidate_cache(key)
    key = key.to_s
    cache.delete(cache_key(key))
    version_by_key.delete(key)
  end
  
  def self.clear_cache
    @version_by_key = {}
  end

private
  
  def self.version_by_key
    @version_by_key ||= {}
  end  
    
  def self.cache_key(key)
    "v:#{key}"
  end
end

class Module
  def version(context = nil)
    key = [self, context].compact.join('_')
    CacheVersion.get(key)
  end

  def increment_version(context = nil)
    key = [self, context].compact.join('_')
    CacheVersion.increment(key)
  end
end

class CacheVersionMigration < ActiveRecord::Migration
  def self.up
    create_table :cache_versions, :id => false do |t|
      t.column :key, :string
      t.column :version, :integer, :default => 0
    end

    add_index :cache_versions, :key, :unique => true
  end

  def self.down
    drop_table :cache_versions
  end
end
