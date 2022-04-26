# frozen_string_literal: true
require 'spec_helper'

RSpec.describe AppConfigFor do

  describe '.verified_style!' do
    
    context 'when given a bad style' do

      it 'raises InvalidEnvInheritanceStyle' do
        expect { AppConfigFor.verified_style!(:foo) }.to raise_error(AppConfigFor::InvalidEnvInheritanceStyle)
      end

      it 'reports what style was used' do
        style = :foo
        expect(AppConfigFor::InvalidEnvInheritanceStyle).to receive(:new).with(style).and_call_original
        AppConfigFor.verified_style!(:foo) rescue nil
      end
      
    end
    
  end

  describe '.version' do
    
    it 'returns a Gem::Version' do
      expect(AppConfigFor.version).to be_a(Gem::Version)
    end
    
  end
    
  describe '.yml_name_from' do
    
    it 'does not convert a Pathname' do
      pathname = Pathname.new('foo/bar')
      expect(pathname).to_not receive(:to_s)
      expect(AppConfigFor.yml_name_from(pathname)).to be(pathname)
    end

    it 'uses Module#name' do
      m = Module.new
      expect(m).to receive(:name).and_return('Foo').at_least(:once)
      expect(AppConfigFor.yml_name_from(m)).to eql('foo.yml')
    end

    it 'uses Class#name' do
      c = Class.new
      expect(c).to receive(:name).and_return('Foo').at_least(:once)
      expect(AppConfigFor.yml_name_from(c)).to eql('foo.yml')
    end

    it 'uses a String directly' do
      expect(AppConfigFor.yml_name_from('Foo')).to eql('foo.yml')
    end

    it 'uses a Symbol converted to a string' do
      expect(AppConfigFor.yml_name_from(:Foo)).to eql('foo.yml')
    end

    it 'uses the name of the class of an Object' do
      expect(AppConfigFor.yml_name_from(binding)).to eql('binding.yml')
    end
    
    it 'underscores the name' do
      expect(AppConfigFor.yml_name_from('FooBar')).to eql('foo_bar.yml')
    end

    it 'replaces slashes with underscores' do
      expect(AppConfigFor.yml_name_from('foo/bar')).to eql('foo_bar.yml')
    end

    context 'working with anonymous objects' do
      
      it 'uses the class hierarchy for classes' do
        expect(AppConfigFor.yml_name_from(Class.new)).to eql('object.yml')
      end

      it 'uses the class hierarchy for modules' do
        expect(AppConfigFor.yml_name_from(Module.new)).to eql('module.yml')
      end

    end
    
    
  end
  
end
