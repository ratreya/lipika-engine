[![Build Status](https://travis-ci.com/ratreya/lipika-engine.svg?branch=master)](https://travis-ci.com/ratreya/lipika-engine)

# Lipika Engine

__LipikaEngine__ is a multi-codepoint, user-configurable, phonetic, Transliteration Engine with built-in support for the Bengali, Devanagari, Gujarati, Gurmukhi, Hindi, Kannada, Malayalam, Oriya, Tamil and Telugu scripts, as well as the [ISO-15919](http://en.wikipedia.org/wiki/ISO_15919) romanisation scheme and [IPA](http://en.wikipedia.org/wiki/International_Phonetic_Alphabet). It includes support for [ITRANS](http://www.aczoom.com/itrans/#onlinedocs), [Baraha](http://www.baraha.com/help/Keyboards/phonetic_keyboard.htm), [Harvard Kyoto](http://en.wikipedia.org/wiki/Harvard-Kyoto), [Barahavat](http://daivajnanam.blogspot.com/p/barahavat.html) and [Ksharanam](http://blog.ambari.sh/2014/03/a-custom-keymap-for-indian-languages.html) transliteration schemes.

> Copyright (C) 2017 Ranganath Atreya

```
This program is free software: you can redistribute it and/or modify it under the terms of the GNU 
General Public License as published by the Free Software Foundation; either version 3 of the License, 
or (at your option) any later version.

This program comes with ABSOLUTELY NO WARRANTY; see LICENSE file.
```

## Usage ##
> **Refer to the full Jazzy generated documentation [here](https://ratreya.github.io/lipika-engine/index.html).**

> **All supported Tranliteration schemes are documented [here](https://github.com/ratreya/lipika-ime/wiki/Transliteration-Schemes)**

LipikaEngine compiles into two separate distributables - iOS and macOS frameworks. It exposes functionality to tranliterate from different schemes to many Indic languages. It also has the ability to reverse transliterate from various Indic languages to schemes. As such, the two functionalities can be used to also transliterate from any supported language to any other supported language. In order to use LipikaEngine, you need to do the following:

1. *Optionally, provide your own configuration by overriding the `Config` class.* See [LipikaConfig](https://github.com/ratreya/lipika-ime/blob/master/Input%20Source/LipikaConfig.swift) in LipikaIME as an example of how to override and leverage `UserDefaults` to provide user configurable options.
```swift
  class LipikaConfig: Config {
      // Override any of the functions that you deem necessary
  }
```

2. *Initialize `Transliterator` and `Anteliterator` as needed.*
* **Option #1**: use a built-in scheme and script
```swift
  let factory = try! LiteratorFactory(config: MyConfig())
  let transliterator = try! factory.transliterator(schemeName: "Barahavat", scriptName: "Kannada")
  let anteliterator = try! factory.anteliterator(schemeName: "Barahavat", scriptName: "Kannada")
```
* **Option #2**: use a [custom scheme](https://github.com/ratreya/google-ime-scm) based on SCM format. In this option, you have to override `customMappingDirectory` variable of `Config` and specify the path at which to look for the custom scheme files.
```swift
  let factory = try! LiteratorFactory(config: MyConfig())
  let transliterator = try! factory.transliterator(customMapping: "MyOwnCustomSCM")
  let anteliterator = try! factory.anteliterator(customMapping: "MyOwnCustomSCM")
```
* **Option #3**: get the built-in mappings, modify them and use them
```swift
  let factory = try! LiteratorFactory(config: MyConfig())
  let mappings = factory.mappings("Barahavat", scriptName: "Kannada")
  // Modify mappings as you see fit
  let transliterator = try! factory.transliterator(schemeName: "Barahavat", scriptName: "Kannada", mappings: mappings)
  let anteliterator = try! factory.anteliterator(schemeName: "Barahavat", scriptName: "Kannada", mappings: mappings)
```

3. *Transliterate any string of alpha-numeric characters.*
```swift
  let result: Literated = transliterator.transliterate("aatreya")
  // result.finalaizedOutput + result.unfinalaizedOutput will have the transliterated string
```

4. *Anteliterate any unicode string in supported language into any supported scheme.*
```swift
  let result: String = anteliterator.anteliterate("आत्रेय")
  // result will have the alpha-numeric characters in the chosen scheme
```
