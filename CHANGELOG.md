## [Alpha Release]

## [0.0.1] - 2022-04-07

- Initial release

## [0.0.2] - 2022-04-12

- Added prefix inheritance.
- Initial inclusion vs extension support.
- Refactored some internal behaviors.

## [0.0.3] - 2022-04-12

- More internal refactoring and miscellaneous bug fixes.

## [0.0.4] - 2022-04-14

- Reduced minimal ActiveSupport version requirements to 5.0.
- Added a legacy support shim for older versions of ActiveSupport.
- Multiple configuration directory support.
- Single configuration name override support.
- Automatically prep gems consumers with the ability to ship with a default configuration. 

## [0.0.4.1] - 2022-04-15

- Reduced minimal Ruby version requirements to 2.3.6
- Bug fix: active_support/configuration_file was still being requested on older ActiveSupport installations.

## [0.0.5] - 2022-04-25

- Full Yard documentation.
- Multiple config directories for file searching can be added at one time.
- Small updates to initializations.
- Started specs.
- Fixed bug in progenitor_prefixes_of that prevented rails and rack prefixes from being used.
- additional_config_directories duped by default to prevent accidental changes.
- add_config_directory now converts its argument to a string via #to_s.

## [0.0.6] - 2022-04-25

- Reading and setting configuration values can now be done directly on the extending class/module.
- Documentation updates.
- Fallback configuration support.
- Requesting configuration for another object that can supply it's own config_files will use those files instead of locally determining them.