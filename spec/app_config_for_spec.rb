# frozen_string_literal: true
require 'spec_helper'

RSpec.describe AppConfigFor do

  context 'Common support methods' do

    let(:env_prefixes) { double }
    
    describe '.add_env_prefix' do
  
      let(:env_prefixes_duped) { double }
  
      before(:each) do
        allow(AppConfigFor).to receive(:env_prefixes).with(false, false).and_return(env_prefixes)
        allow(AppConfigFor).to receive(:env_prefixes).with(false).and_return(env_prefixes)
  
        allow(env_prefixes).to receive(:push).and_return(env_prefixes)
        allow(env_prefixes).to receive(:unshift).and_return(env_prefixes)
        allow(env_prefixes).to receive(:uniq!)
  
        allow(AppConfigFor).to receive(:env_prefixes).with(false).and_return(env_prefixes_duped)
      end
  
      it 'fetches the current prefixes without duplication' do
        expect(AppConfigFor).to receive(:env_prefixes).with(false, false)
        AppConfigFor.add_env_prefix(:foo)
      end
  
      it 'adds to the beginning of the array if at_beginning is true' do
        expect(env_prefixes).to receive(:unshift)
        AppConfigFor.add_env_prefix(:foo, true)
      end
  
      it 'adds to the end of the array if at_beginning is false' do
        expect(env_prefixes).to receive(:push)
        AppConfigFor.add_env_prefix(:foo, false)
      end
  
      it 'adds to the beginning of the array by default' do
        expect(env_prefixes).to receive(:unshift)
        AppConfigFor.add_env_prefix(:foo)
      end
      
      it 'uses prefix_from to convert the prefix as needed' do
        prefix = double
        expect(AppConfigFor).to receive(:prefix_from).with(prefix)
        AppConfigFor.add_env_prefix(prefix)
      end
  
      it 'ensures the prefixes are uniq' do
        expect(env_prefixes).to receive(:uniq!)
        AppConfigFor.add_env_prefix(:foo)
      end
      
      it 'returns the current prefixes duped' do
        expect(AppConfigFor).to receive(:env_prefixes).with(false).and_return(env_prefixes_duped)
        expect(AppConfigFor.add_env_prefix(:foo)).to eq(env_prefixes_duped)
      end
      
    end
  
    describe ".env_name" do
      
      before(:each) do
        allow(ENV).to receive(:[])
      end
      
      it 'defaults prefixes to env_prefixes' do
        expect(AppConfigFor).to receive(:env_prefixes).and_return(env_prefixes)
        AppConfigFor.env_name
      end
  
      it 'can accept a single prefix' do
        prefix = double
        expect(AppConfigFor).to receive(:Array).with(prefix).and_call_original
        AppConfigFor.env_name(prefix)
      end
      
      it 'locates the first environment variable that is not blank' do
        prefixes = %w(a b c d).map { |x| double(to_s: x) }
        env_value = double
        
        expect(ENV).to receive(:[]).with(prefixes[0].to_s.upcase + '_ENV').and_return(nil)
        expect(ENV).to receive(:[]).with(prefixes[1].to_s.upcase + '_ENV').and_return('')
        expect(ENV).to receive(:[]).with(prefixes[2].to_s.upcase + '_ENV').and_return(env_value)
        prefixes[3..-1].each { |prefix| expect(ENV).to_not receive(:[]).with(prefix) }
        
        expect(AppConfigFor.env_name(prefixes)).to eq(env_value)
      end
  
      it 'defaults to development' do
        expect(AppConfigFor.env_name).to eq('development')
      end
      
    end
  
    describe '.env_prefixes' do
      
      it 'defaults to [:rails, :rack]' do
        expect(AppConfigFor.env_prefixes).to eq([:rails, :rack])
      end
      
      it 'ignores the first parameter' do
        _true = AppConfigFor.env_prefixes(true)
        _false = AppConfigFor.env_prefixes(true)
        expect(_true).to eq(_false)
      end

      it 'returns a duplicate array if dup is true' do
        expect(AppConfigFor.env_prefixes(:ignored, true)).to_not equal(AppConfigFor.instance_variable_get(:@env_prefixes))
      end

      it 'returns the original array if dup is false' do
        expect(AppConfigFor.env_prefixes(:ignored, false)).to equal(AppConfigFor.instance_variable_get(:@env_prefixes))
      end

      it 'defaults to dup true' do
        expect(AppConfigFor.env_prefixes(:ignored)).to_not equal(AppConfigFor.instance_variable_get(:@env_prefixes))
        expect(AppConfigFor.env_prefixes).to_not equal(AppConfigFor.instance_variable_get(:@env_prefixes))
      end
      
    end
  
    

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
  
end
