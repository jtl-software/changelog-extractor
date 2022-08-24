# Common Definition
Die Deutsche Übersetzung is nur für ein besseres Verständnis. maßgeben ist die Englische Version  
>Ein Beispiel ist in `example.md` zu finden
## Überschrift
Alles vor der ersten Version wird ignoriert

## Besonderheiten
Markdown ist ein kompliziertes Format, ein paar Dinge sind zu beachten:
- __Zeilenumbruch__: für eine neue Zeile musst du zwei (2) Leerzeichen an das Ende der vorherigen Zeile schreiben
- __Fett__: für einen fett gedruckten Text musst du `**` oder `__` vor und nach dem Wort schreiben
- _Kursiv_: für einen kursiven Text musst du `*` oder `_` vor und nach dem Wort schreiben
- [Links](#): für einen Link musst du `[text](url)` schreiben
- __Überschriften__: für eine Überschrift musst du `#` und ein Leerzeichen vor dem Text schreiben
  - Für Levels (wie h2 und h3) musst du die mehr `#` verwenden, z.B. `##` für Level 2, `###` für Level 3 
- __Listen__: für eine Liste musst du `-` oder `*` und ein Leerzeichen vor den Text schreiben
- Mehr Markdown Syntax kann [hier (engl.)](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)
  gefunden werden

## Versionen (Erforderlich)
Version muss eine Level 2 Überschrift sein und sollte [Semantische Versioning](https://semver.org/) folgen.  
Du kannst eine `unreleased` Version hinzufügen, diese wird ignoriert

## Sicherheitsupdate markierung (Optional)
Die Sicherheitsupdate markierung muss **fett** gedruckt sein und in derselben Zeile sein wie die Version.  
Das verwendete Wort ist nicht relevant, solange es **fett** ist.

## Veröffentlichungsdatum (Optional)
Das Veröffentlichungsdatum muss *kursiv* gedruckt sein und in derselben Zeile sein wie die Version.

## Kommentar (Optional)
Der Kommentar muss zwischen der Version und den Änderungen liegen. HTML ist erlaubt.  
Wenn du eine Liste in den Kommentar hast, musst du diese einrücken (mindesten 4 Leerzeichen) oder der Parser erkennt es als Änderungen.

## Änderungen (Erforderlich)
Änderungen müssen zwischen zwei Versionen, als Liste, definiert sein.
Eine Änderung kann aus folgendem bestehen:

### Ticket-ID (Optional)
Die Ticket-ID muss im Jira Format sein (`[A-Z][A-Z0-9]+-[0-9]+`, z.B. `ABC-123`) oder muss ein Link sein.

### Änderung Text (Erforderlich)
Der Text ist der Rest der Zeile.  

