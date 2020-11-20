# secret-santa-o-matic

Perl/Tk script to automatically determine a random sequence of Secret Santas for a list of people. 

- includes the possibility to set invalid (i.e. forbidden) combinations. 
- generates .txt-files as output that can be sent to the individual people so that nobody knows who is Secret Santa for whom (calls Thunderbird email client).
- will terminate after 20 tries if no valid sequence can be found. 

## Installation 

Checkout the repository. 

The application requires a `perl` installation and the module `Config::Simple` to run.

To use the `Compose emails` feature, the *Thunderbird* email client needs to be installed. 


## Configuration

Edit the `app.cfg` file to modify the configuration

- List all prospective secret santas in the *[people]* section under the *names* option, e.g. `names="Alice,Bob,Eve,Zoe"`
- Optionally add a row in the *[illegal]* section with a person's name as key and a comma-separated list of people who you want to exclude as gift recipients for that person, e.g. `Bob="Alice,Zoe"`

## Execution

Call

`perl secret-santa-o-matic.pl` 

## Acknowledgement / License

In the generated email body, I use the ASCII art image "elf with gift", 11/97 by Joan G. Stark (aka Spunk). If you reuse this portion of the script, please be informed that the use of said ASCII art is permitted for personal (non-commercial) use only and requires leaving the artists initials ("jgs") on the picture (see https://asciiart.website/joan/www.geocities.com/SoHo/7373/please.html for details).
