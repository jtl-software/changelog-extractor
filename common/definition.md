# Common Definition
>See `example.md` for more examples.
## Heading
Everything before the top most Version is ignored, so you can write there whatever you want or leave it empty

## Caveats
Markdown can be a bit complicated, things to remember are:
- __Newlines__: for a new Line you need to end the previous one with a two (2) spaces
- __Bold__: for a bold text can be written with `**` or `__` before and after the word
- _Italic_: for an italic text can be written with `*` or `_` before and after the word
- [Links](#): for a link you need to write `[text](url)`
- __Headers__: for a header you need to start a line with `#` and a space, then the text
  - For Levels (like h2 and h3) you need to increase the number auf `#`, for example `##` is level 2, `###` is level 3
- __List__: for a list you need to write `-` or `*` followed by a space before the text
- more Markdown syntax can be found [here](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)


## Versions (Required)
Version must be defined with a Level 2 Heading and should follow [Semantic Versioning](https://semver.org/)  
You may add a `unreleased` version, this will be ignored

## Security Flag (Optional)
The Security Flag must be defined by being **BOLD** and must be in the same line as the Version
The word used is not important, as long as it is bolded.

## Release Date (Optional)
The Release Date must be defined by being *ITALIC* and must be in the same line as the Version

## Release Comment (Optional)
The Release Comment must be between the Version and the Changes, HTML is allowed  
If you want to have a list in the comment, you need to indent it with at least 4 spaces or the parsers detects it as changes 

## Changes (Required)
Changes must be between two Version defined as a List
A Single Change can be made up of:

### Ticket ID (Optional)
The Ticket ID must be in the Jira Format (`[A-Z][A-Z0-9]+-[0-9]+`) or must be a link

### Change text (Required)
The Change text is the rest of the list line  

