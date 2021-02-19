# Testing Instructions

## Run specs

```shell
$ rspec
```

## Generate PDF files for testing

On Ubuntu:
```shell
$ echo "The day is bright" > day.txt
$ libreoffice --convert-to "pdf" day.txt 
```