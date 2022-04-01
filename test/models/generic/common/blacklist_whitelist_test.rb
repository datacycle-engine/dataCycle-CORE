# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Generic::Common::BlacklistWhitelistFunctions do
  subject do
    DataCycleCore::Generic::Common::BlacklistWhitelistFunctions
  end

  describe 'reject_attribute' do
    it 'rejects an simple attribue' do
      data = { a: 1, b: 2 }
      hash = subject.reject_attribute(data, :a)
      assert_equal({ b: 2 }, hash)
    end

    it 'rejects path as array and as value' do
      data = { a: 1, b: 2 }
      hash = subject.reject_attribute(data, :a)
      hash2 = subject.reject_attribute(data, [:a])
      assert_equal(hash2, hash)
    end

    it 'rejects attribute in a deep hash' do
      data = { a: 1, b: { a: 1 } }
      hash = subject.reject_attribute(data, [:b, :a])
      assert_equal({ a: 1 }, hash)
    end

    it 'rejects attribute in an array' do
      data = { a: 1, b: [{ a: 1 }, { c: 1 }] }
      hash = subject.reject_attribute(data, [:b, :a])
      assert_equal({ a: 1, b: [{ c: 1 }] }, hash)
    end

    it 'rejects attribue in an array and removes the empty array' do
      data = { a: 1, b: [{ a: 1 }, { a: 2 }] }
      hash = subject.reject_attribute(data, [:b, :a])
      assert_equal({ a: 1 }, hash)
    end

    it 'rejects also more complicated cases' do
      data = { a: 1, b: [{ a: 1 }, { a: { c: [{ d: 1 }] } }] }
      hash = subject.reject_attribute(data, [:b, :a, :c, :d])
      assert_equal({ a: 1, b: [{ a: 1 }] }, hash)
    end
  end

  describe 'select_attributes' do
    it 'selects more than one attribute' do
      data = { a: 1, b: 2, c: 3 }
      hash = subject.select_attributes(data, [:a, :b])
      assert_equal({ a: 1, b: 2 }, hash)
    end

    it 'selects single paths as array and as value' do
      data = { a: 1, b: 2, c: 3 }
      hash = subject.select_attributes(data, [:a, :b])
      hash2 = subject.select_attributes(data, [[:a], [:b]])
      assert_equal(hash2, hash)
    end

    it 'selects all attributes that start with "@"' do
      data = { a: 1, '@id' => 2 }
      hash = subject.select_attributes(data, [:b])
      assert_equal({ '@id' => 2 }, hash)
    end

    it 'selects attribute in a deep hash' do
      data = { a: 1, b: { a: 1, c: 3 } }
      hash = subject.select_attributes(data, [[:b, :a]])
      assert_equal({ b: { a: 1 } }, hash)
    end

    it 'selects attribute in an array' do
      data = { a: 1, b: [{ a: 1 }, { c: 1 }] }
      hash = subject.select_attributes(data, [[:b, :a]])
      assert_equal({ b: [{ a: 1 }] }, hash)
    end

    it 'selects attribues in an array' do
      data = { a: 1, b: [{ a: 1 }, { a: 2 }, { b: 3 }] }
      hash = subject.select_attributes(data, [[:b, :b]])
      assert_equal({ b: [{ b: 3 }] }, hash)
    end

    it 'selects deep nested attributes' do
      data = { a: 1, b: [{ a: 1 }, { a: { b: 1 } }] }
      hash = subject.select_attributes(data, [[:b, :a, :b]])
      assert_equal({ b: [{ a: { b: 1 } }] }, hash)
    end

    it 'select even more complicated cases' do
      data = { a: 1, b: [{ a: 1 }, { a: { c: [{ d: 1 }] } }] }
      hash = subject.select_attributes(data, [[:a], [:b, :a, :c, :d]])
      assert_equal({ a: 1, b: [{ a: { c: [{ d: 1 }] } }] }, hash)
    end
  end

  describe 'apply_blacklist' do
    it 'rejects several attributes' do
      data = { a: 1, b: 2, c: 3 }
      hash = subject.apply_blacklist(data, [:a, :c])
      assert_equal({ b: 2 }, hash)
    end

    it 'rejects several attributes, given als array' do
      data = { a: 1, b: 2, c: 3 }
      hash = subject.apply_blacklist(data, [[:a], [:c]])
      assert_equal({ b: 2 }, hash)
    end

    it 'rejects attributes in a deep hash' do
      data = { a: 1, b: { a: 1, c: 3 } }
      hash = subject.apply_blacklist(data, [[:b, :a], [:b, :c]])
      assert_equal({ a: 1 }, hash)
    end

    it 'rejects deep nested attributes' do
      data = { a: 1, b: [{ a: 1 }, { a: { b: 1 } }] }
      hash = subject.apply_blacklist(data, [:a, [:b, :a, :b]])
      assert_equal({ b: [{ a: 1 }] }, hash)
    end
  end

  describe 'apply_whitelist' do
    it 'rejects several attributes' do
      data = { a: 1, b: 2, c: 3 }
      hash = subject.apply_whitelist(data, [:a, :c])
      assert_equal({ a: 1, c: 3 }, hash)
    end

    it 'rejects several attributes, given als array' do
      data = { a: 1, b: 2, c: 3 }
      hash = subject.apply_whitelist(data, [[:a], [:c]])
      assert_equal({ a: 1, c: 3 }, hash)
    end

    it 'rejects attributes in a deep hash' do
      data = { a: 1, b: { a: 1, c: 3 } }
      hash = subject.apply_whitelist(data, [[:b, :a], [:b, :c]])
      assert_equal({ b: { a: 1, c: 3 } }, hash)
    end

    it 'rejects deep nested attributes' do
      data = { a: 1, b: [{ a: 1 }, { a: { b: 1 } }] }
      hash = subject.apply_whitelist(data, [:a, [:b, :a, :b]])
      assert_equal({ a: 1, b: [{ a: { b: 1 } }] }, hash)
    end
  end
end
