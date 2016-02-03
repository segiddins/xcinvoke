## 0.2.1

##### Bug Fixes

* Ensure that `xcrun` is invoked with the full path, avoiding hanging when
  Xcode 4.3.x is installed.  
  [Samuel Giddins](https://github.com/segiddins)
  [#3](https://github.com/segiddins/xcinvoke/issues/3)


## 0.2.0

##### Enhancements

* Return `Xcode#swift_version` as a `Version` object.  
  [Samuel Giddins](https://github.com/segiddins)

##### Bug Fixes

* The entirety of `DYLD_FRAMEWORK_PATH` and `DYLD_LIBRARY_PATH` are no longer
  overwritten in the generated Xcode environment.  
  [Samuel Giddins](https://github.com/segiddins)


## 0.1.0

##### Enhancements

* Initial release.  
  [Samuel Giddins](https://github.com/segiddins)
