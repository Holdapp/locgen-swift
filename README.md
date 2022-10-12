# locgen-swift

Generate *.strings translation files for multiple languages from online Excel sheets. 

## Usage

```shell
locgen-swift --input "https://docs.google.com/spreadsheets/d/e/2PACX-1vTKW4xUbtwf_IJnYnlhujaTKhob2K0qzZ4figDzo38UZx-Y2JAEq-Agj7eEY_mu0FGreSQrBLv0ajUO/pub?output=xlsx" --sheets "Sheet 1" --map "map.yml"
````

_All params are required_

- `--input` - web URL or local path to **xlsx** file
- `--sheets` - **xlsx** sheet name[s] with translations. If not specified, the first sheet will be used.
- `--map` - web URL or local path to map (yaml) file ([example](map.yml))

## Build

### Requirements

* Xcode command-line tools
* Swift 5

### Building from source

Clone repository, then from project directory run:

```shell
make
```

`.build` directory will be created with `locgen-swift` executable at `.build/release/locgen-swift`.

If you want to install compiled executable, run:

```shell
make install
```
