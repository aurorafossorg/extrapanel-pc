# Indent style

This document explains the codestyle that the Extra Panel project uses. We use this rules to keep our code spaghetti safe and with a better look.

This document is valid only for the **PC** version/repository.

This codestyle is a modified version of Aurora Framework's codestyle.

## Extra Panel Codestyle Specification
This specification is based on K&R variants: 1TBS, Stroustrup, Linux kernel and BSD KNF codestyles.

<!-- TOC depthFrom:3 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Comments](#comments)
	- [Documentation Comments](#documentation-comments)
	- [Code Comments](#code-comments)
- [Naming](#naming)
	- [Types](#types)
	- [Functions](#functions)
	- [Objects and Variables](#objects-and-variables)
	- [Constants](#constants)
	- [Acronyms](#acronyms)
- [Lines](#lines)
	- [Length](#length)
	- [Ending](#ending)
- [File encoding](#file-encoding)
- [Braces](#braces)
- [Tab idention](#tab-idention)
	- [Single and multiple statements](#single-and-multiple-statements)
- [Spaces](#spaces)
	- [Pointers](#pointers)

<!-- /TOC -->

### Comments
In Extra Panel code files, we have a very well defined anatomy for comment blocks. You have two types of comments: documentation comments and code comments. All of them need to be written in English and well explained for easier development of other programmers that want to contribute to the project.

#### Documentation Comments
At the moment of writing, we have yet to decide which documentation framework and style to use. For this reason, do not start documenting code until this matter is decided.

#### Code Comments
The purpose of these comments is to help people understand an instruction or even a block of code. We use the common syntax of a comment: `//` and:
```d
/*
block comments
*/
```
Here you just need to be clear on what you want to explain to the programmer, so no formal language is needed and, for better communication, use easy words.

Do **not** create TODO, FIXME, XXX, HACK or similar comments in the code. This is a bad pratice that only pollutes the code and is a very shallow way of notifying developers. Opening an issue, describing the problem and where it is located, and assigning/tagging the developers is a much better and straightforward way.

### Naming
To name our code we use typical methods adopted in programming to know what's the type of the instructions used. We use a different name idention for types, functions and objects/variables.

#### Files

For naming source files we use lower-case names. Use single words for easier readability and understanding of the file's purpose.

#### Types
For types such as a `class`, `struct`, `enum`, etc, you should use PascalCase, which means that the first letter of each concatenated word is capitalized. Here are some examples:

- `BackColor`
- `TimeUtc`
- `Timer`

#### Functions
For functions you should use camelCase, which means that the first word is in lowercase and the rest of the words start with a capital letter. Here are some examples:
- `getName()`
- `setName()`
- `isNull()`

#### Objects and Variables
For objects or variables we write them in camelCase.

**Note**: Words that are already assigned by the language (keywords) should have an `_` at the end.

#### Constants
For **immutable** data use capital letters. For *const* variables use the regular camelCase expression. For example:
```d
immutable int MARGIN_DEFAULT = 20;

public void abs(const int value) {
	...
}
```

#### Acronyms
If the first letter is uppercase then the whole acronym should have uppercase letters. Else if the first letter is lowercase then the whole acronym should have lowercase letters. Here are some examples:
- `UTCTime`
- `asciiArt`

### Lines
Line structure is important for programmers. If lines are separated and with a length limit, code readability is improved and the development workflow is way better. It's important that blank lines exist and may be added to separate different blocks of code. It doesn't affect the compiler in any way, so there's no excuse for not using them.

#### Length
When talking about soft limit, the lines should not pass 80 characters. For hard limit, lines must not pass 120 characters.

#### Ending
For line ending we use Unix LF (linefeed). If you are developing on Windows, you should use a linefeed compatible editor.

### File encoding
You must use 8-bit unicode, UTF-8.

### Braces
Always open braces in the same line as the declarations, whether it's a function, a control flow, etc. To close braces you must always do it in a new line, unless its has no body.

### Tab idention
Use tab instead of spaces for tab idention, if supported in the language, and configure your editor for 4 spaces in a single tab. Then, for alignment, use spaces. This helps to reduce significantly the project size.

#### Single and multiple statements
Do not unnecessarily use braces where a single statement will do.
```d
if (condition)
	action();
```
and
```d
if (condition)
	do_this();
else
	do_that();
```

This does not apply if only one branch of a conditional statement is a single statement; in the latter case use braces in both branches:
```d
if (condition) {
	do_this();
	do_that();
} else {
	otherwise();
}
```

### Spaces
Do not add a space after keywords, such as `if`, `switch`, `case`, `for`, `do`, `while`, etc. Also don't add spaces around (inside) parenthesized expressions.

#### Pointers
When declaring pointer data or a function that returns a pointer type, the preferred use of * is adjacent to the type name and not adjacent to the data or function name. For example:
```d
char* name;
unsigned int memory(char* ptr, char** retptr);
char* convert(string* s);
```