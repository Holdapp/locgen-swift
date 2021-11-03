### Installation
run this command in terminal
```shell
curl -s https://raw.githubusercontent.com/Holdapp/locgen-swift/main/install.sh | bash
```

### Usage example
```shell
locgen-swift --input "https://docs.google.com/spreadsheets/d/e/2PACX-1vTKW4xUbtwf_IJnYnlhujaTKhob2K0qzZ4figDzo38UZx-Y2JAEq-Agj7eEY_mu0FGreSQrBLv0ajUO/pub?output=xlsx" --sheet "Sheet 1" --map "map.yml"

````
_All params are required_

- `--input` - web URL or local path to **xlsx** file
- `--sheet` - name of **xlsx** sheet that contains translations
- `--map` - web URL or local path to map (yaml) file ([example](map.yml))