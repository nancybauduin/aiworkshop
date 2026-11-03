# AI Workshop - OpenEdge ABL Project

An OpenEdge ABL workshop project demonstrating the Business Entity pattern with a layered architecture.

## Contents

- `src/business/` - Business entity classes (CustomerEntity, EntityFactory) and dataset include files
- `src/` - AppBuilder window files (CustomerWin.w, ItemWin.w)
- `.windsurf/` - Windsurf rules and workflows for ABL development
- `doc/` - Documentation on the business entity architecture pattern
- `dump/` - sports2000 database schema

## Architecture

The project follows a three-layer architecture:

1. **UI Layer** - Window procedures that never touch the database directly
2. **Business Entity Layer** - Classes inheriting from `OpenEdge.BusinessLogic.BusinessEntity`, managed via a singleton EntityFactory
3. **Database Layer** - sports2000 database accessed only through data-sources

See `doc/business-entity-pattern.md` for details.
