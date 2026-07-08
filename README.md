## MFVT Linux Validator — data-driven menus and input file mappings

This repo now supports explicit input-property mapping in menus/*.menu files.

Menu file format
- Standard (legacy):
  command=Label
- Data-driven (preferred):
  command:inputProperty=Label
  Example: validateMarcBib:marcBib=MARC Bib

Behavior
- When a menu item has an explicit inputProperty, the menu engine will read that property from validator.properties and pass the resulting path as the entity input-file parameter to the Java validator.
- If explicit mapping is absent the engine attempts to infer the property (marcBib, marcHolding, items, patrons, loans, vendors).
- Use the main menu option "Set Input File Paths" to populate entity file paths interactively.

Java invocation
- The Java wrapper (bin/java.sh) supplies the following arguments to your Java validator:
  --migrationForm <path> --fieldMapping <path> --dateFormat <format> --inputFile <path> <validator.properties>
- If you prefer a different argument format, update bin/java.sh accordingly.
