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
  
    describe '.namespace_of' do
      
      it 'determines the lexical namespace of an class' do
        expect(AppConfigFor.namespace_of(self.class)).to eq(RSpec::ExampleGroups::AppConfigFor::CommonSupportMethods)
      end

      it 'the namespace of an instance is the same as the same as the class' do
        expect(AppConfigFor.namespace_of(self)).to eq(AppConfigFor.namespace_of(self.class))
      end

      it 'the namespace of a class name is the same as the same as the class' do
        expect(AppConfigFor.namespace_of(self.class.name)).to eq(AppConfigFor.namespace_of(self.class))
      end

      it 'is nil if there is no surrounding namespace' do
        expect(AppConfigFor.namespace_of(Object)).to be_nil
        expect(AppConfigFor.namespace_of('blarg')).to be_nil
      end
      
      it 'uses nearest_named_class if not given a string' do
        expect(AppConfigFor).to receive(:nearest_named_class).with(self).and_return(Object)
        AppConfigFor.namespace_of(self)
      end

      it 'uses a string as the name of a class and does not call nearest_named_class' do
        expect(AppConfigFor).to_not receive(:nearest_named_class)
        AppConfigFor.namespace_of(self.class.name)
      end

    end

    describe '.nearest_named_class' do

      it 'is the class of the instance given' do
        expect(AppConfigFor.nearest_named_class('')).to eql(String)
      end

      it 'is the same as a named class given' do
        expect(AppConfigFor.nearest_named_class(String)).to eql(String)
      end

      it 'is the nearest super class that has a name' do
        expect(AppConfigFor.nearest_named_class(Class.new(self.class))).to eql(self.class)
      end

      it 'is Module for anonymous modules' do
        expect(AppConfigFor.nearest_named_class(Module.new)).to eql(Module)
      end

      it 'is an anonymous class if that class provides a name' do
        c = Class.new
        c.define_singleton_method(:name) { 'Foo' }
        expect(AppConfigFor.nearest_named_class(c)).to eql(c)
      end

    end

    describe '.parent_of' do

      it 'is the superclass of a class' do
        expect(AppConfigFor.parent_of(self.class)).to eql(self.class.superclass)
      end

      it 'is the class of an instance' do
        expect(AppConfigFor.parent_of(self)).to eql(self.class)
      end

      it 'is the named class for a string' do
        expect(AppConfigFor.parent_of(self.class.name)).to eql(self.class)
      end

      it 'is nil if the string cannot be resolved to an existing class name' do
        expect(AppConfigFor.parent_of('foo')).to be_nil
      end

    end

    describe '.parents_of' do

      it 'is an array of all hierarchical parents of the given object' do
        foo = Class.new
        bar = Class.new(foo)
        baz = Class.new(bar)
        expect(AppConfigFor.parents_of(baz.new)).to eq([baz, bar, foo, Object, BasicObject])
      end

      it 'is an empty array if no parent can be located' do
        expect(AppConfigFor.parents_of('wtf')).to eq([])
      end

    end

    describe '.prefix_from' do

      it 'converts a String to an underscored symbol' do
        expect(AppConfigFor.prefix_from('Some::App')).to eql(:some_app)
      end

      it 'converts "/" characters to underscores' do
        expect(AppConfigFor.prefix_from('some/app')).to eql(:some_app)
      end

      it 'uses the basename without an extension for a Pathname' do
        expect(AppConfigFor.prefix_from(Pathname.new('/foo/bar/some_app.yml'))).to eql(:some_app)
      end

      it 'does not attept to convert symbols' do
        s = :SomeApp
        expect(AppConfigFor.prefix_from(s)).to eql(s)
      end

      it 'uses the name of the nearest named class if not given a Symbol, String, or Pathname' do
        e = AppConfigFor::Error.new
        expect(AppConfigFor).to receive(:nearest_named_class).with(e).and_call_original
        expect(AppConfigFor.prefix_from(e)).to eql(:app_config_for_error)
      end

    end

    describe '.progenitor_of' do

      it 'search uses .namespace_of when inheritance style is :namespace' do
        object = double
        expect(AppConfigFor).to receive(:namespace_of).with(object)
        AppConfigFor.progenitor_of(object, :namespace)
      end

      it 'search uses .parent_of when inheritance style is :class' do
        object = double
        expect(AppConfigFor).to receive(:parent_of).with(object)
        AppConfigFor.progenitor_of(object, :class)
      end

      it 'search uses .namespace_of when inheritance style is :namespace_class' do
        object = double
        expect(AppConfigFor).to receive(:namespace_of).with(object)
        AppConfigFor.progenitor_of(object, :namespace_class)
      end

      it 'search uses .parent_of when inheritance style is :class_namespace' do
        object = double
        expect(AppConfigFor).to receive(:parent_of).with(object)
        AppConfigFor.progenitor_of(object, :class_namespace)
      end

      it 'search defaults to :namespace' do
        object = double
        expect(AppConfigFor).to receive(:namespace_of).with(object)
        AppConfigFor.progenitor_of(object)
      end

      it 'verifies the style given' do
        style = :foo
        object = double
        expect(AppConfigFor).to receive(:verified_style!).with(style, object).and_return('x')
        AppConfigFor.progenitor_of(object, style)
      end

      it 'identifies the first env_prefix namespace/parent of an object' do
        acf_namespace = double(env_prefixes: [])
        normal_namespace = double
        object = double
        expect(AppConfigFor).to receive(:namespace_of).with(object).and_return(normal_namespace)
        expect(AppConfigFor).to receive(:namespace_of).with(normal_namespace).and_return(acf_namespace)
        expect(AppConfigFor.progenitor_of(object)).to eql(acf_namespace)
      end

      it 'is nil if a progenitor cannot be located' do
        object = double
        expect(AppConfigFor).to receive(:namespace_of).with(object).and_return(nil)
        expect(AppConfigFor.progenitor_of(object)).to be_nil
      end

    end

    describe '.progenitors_of' do

      it 'is an empty array if style is :none' do
        object = double
        expect(AppConfigFor.progenitors_of(object, :none)).to eq([])
      end

      it 'is an empty array if the object is nil' do
        expect(AppConfigFor.progenitors_of(nil, :none)).to eq([])
      end

      it 'uses progenitor with the style :namespace if called with the style :namespace' do
        expect(AppConfigFor).to receive()
        AppConfigFor.progenitors_of(object, :namespace)
      end

      it 'verifies the style given' do
        style = :foo
        object = double
        expect(AppConfigFor).to receive(:verified_style!).with(style, object).and_return(:none)
        AppConfigFor.progenitors_of(object, style)
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
