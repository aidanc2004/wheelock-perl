# wheelock-perl

`usage: wheelock-perl.pl [--period=breakfast/lunch/etc] [--date=YYYY-MM-DD] [--all] [--json]`

Get the current menu of Acadia University's dining hall Wheelock hall using the Dine on Campus API. It might also work with other schools using Dine on Campus CA.

## Flags

- `--help`: Shows program usage.
- `--period`: What period of the menu should be shown. Breakfast, lunch, dinner, etc.
- `--date`: The date to get the menu for in YYYY-MM-DD format. (ex. May 24th 2024 is 2024-05-24)
- `--all`: Ignore hidden categories and show all.
- `--json`: Output the API as JSON rather than printing the menu.

## Config

- `school`: School's slug in the Dine on Campus API.
- `location`: Name of the location in the Dine on Campus API.
- `hidden_categories`: Array of category names that shouldn't be shown.
