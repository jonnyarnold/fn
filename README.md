# fn
Prototype functional programming language

I've always been insterested in building a programming language, so I'm having a go. I'm following the [Kaleidoscope tutorial](http://llvm.org/docs/tutorial/LangImpl1.html), but using Ruby to make it a bit quicker to do. (The down side of this, of course, is that I'm likely to need to re-write in C/C++ before it has decent performance.)

Sorry about the mess, I don't really know what I'm doing.

## Design Goal

A minimalist functional programming language.

## Current Status

If you run `ruby interpreter.rb` you will get an Abstract Syntax Tree of the code in `example.fn`.
