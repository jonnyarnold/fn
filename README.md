# fn
Prototype functional programming language

I've always been interested in building a programming language, so I'm having a go. I'm following the [Kaleidoscope tutorial](http://llvm.org/docs/tutorial/LangImpl1.html), but using Ruby to make it a bit quicker to do. (The down side of this, of course, is that I'm likely to need to re-write in C/C++ before it has decent performance.)

Sorry about the mess, I don't really know what I'm doing.

## Design Goal

A minimalist functional programming language.

## Language Tour

Check out [tour.fn](tour.fn).

## Current Status

If you run `ruby interpreter.rb` the file `tour.fn` will be run.

If you run `ruby repl.rb` you can try typing on a very basic REPL! (How basic? Well, it evaluates as soon as you press enter, so make sure you get the whole expression on a single line!)

## Usage

Please don't. It doesn't have some basic things yet (like floats).
