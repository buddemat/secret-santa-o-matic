#!/usr/bin/env perl

############################################################################################
# Secret-Santa-O-Matic                                                                     #
#                                                                                          #
# written 2015-2021 by Matthias Budde                                                      # 
#                                                                                          #
# Perl/Tk script to automatically determine a random sequence of Secret Santas for a list  #
# of people. Includes the possibility to set invalid (i.e. forbidden) combinations.        # 
# Generates .txt-files as output that can be sent to the individual people so that nobody  #
# knows who is Secret Santa for whom.                                                      #
#                                                                                          #
# Will terminate after 20 tries if no valid sequence can be found.                         #
#                                                                                          #
# Uses ASCII art "elf with gift", 11/97 by Joan G. Stark (aka Spunk), taken from           #
#    http://www.chris.com/ascii/index.php?art=holiday/christmas/other                      #
#    The use of said ASCII art is permitted for personal (non-commercial) use only and     #
#    requires leaving the artists initials ("jgs") on the picture.                         # 
#    See https://asciiart.website/joan/www.geocities.com/SoHo/7373/please.html for details #
#                                                                                          #
############################################################################################

use strict;
use warnings;
use Cwd;
use Tk;
use File::Path qw( make_path );
use Config::Simple;
require Tk::TextUndo;

my $version = "v0.99.1";

# Read config file into hash
my $cfg = new Config::Simple('app.cfg');
my %config = $cfg->vars();

my $option_resultspath = cwd()."/".$config{"settings.resultsdir"}."/";
# Create output path if it does not exist
if ( !-d $option_resultspath ) {
    make_path $option_resultspath or die "Failed to create path: $option_resultspath";
}

# 
my @emailLanguages = sort(split(",", $config{"email.languages"}));

# Load secret santa participants here 
my @allPeople = sort(split(",", $config{"people.names"}));
my @selectPeople = sort(split(",", $config{"people.selected"}));

my @result;
my $result_status = 0;

# Perl/Tk GUI
my $mainWindow = MainWindow->new();

$mainWindow->title(" Secret-Santa-O-Matic ".$version);

my $topFrame = $mainWindow->Frame()->pack();

my $topLeftFrame = $topFrame->Frame()->pack(
    -side => 'left',
    -anchor => 'n',
);

my $peopleListBox = $topLeftFrame->Scrolled("Listbox",
    -selectmode => 'multiple',
    -scrollbars => "osoe",
    -exportselection => 0,
    -height => scalar(@allPeople) >= $config{"gui.maxlistheight"} ?  $config{"gui.maxlistheight"} : scalar(@allPeople) 
)->pack();

my $buttonFrame = $topLeftFrame->Frame()->pack();

my $invertButton = $buttonFrame->Button(
    -text => 'invert',
    -command => sub{ invert_selection(); },
)->pack(
    -side => 'left',
);

# # TODO: Edit-Button to edit and/or save to config file
# my $editButton = $buttonFrame->Button(
#     -text => 'settings',
#     -command => sub{ print "not yet implemented...\n"; },
# )->pack();

my $topRightFrame = $topFrame->Frame()->pack(
    -side => 'right',
    -anchor => 'n',
);
my $consoleText = $topRightFrame->TextUndo()->pack();
my $optionsFrame = $topRightFrame->Frame()->pack();


my $doButton = $optionsFrame->Button(
    -text => 'Draw lots',
    -command => sub{ 
        $consoleText->delete("1.0", 'end');
        my @selection = $peopleListBox->curselection();
        clean_results_directory();
        (my $result_arr_ref, $result_status) = generate_sequence(\@selection);
        @result = @$result_arr_ref;
        set_email_button($result_status and $config{'settings.writefiles'});
        if($result_status and $config{'settings.writefiles'}) {
            print_email_option();
        }
    },
)->pack(
    -anchor => 'n',
    -side => 'bottom',

);

my $opionsLabel = $optionsFrame->Label(
	-text => 'Options:',
)->pack(
    -side => 'left',
);

my $languageDropDown = $optionsFrame->Optionmenu(
    -variable => \$config{"email.activelang"}, 
    -options => \@emailLanguages,
    -command => sub{ 
        unless ($result_status) {
            $consoleText->delete("1.0", 'end');
            print_options();
        } elsif ($config{'settings.writefiles'})  {
            $consoleText->undo;
            print_email_option();
        }
    },
)->pack(
    -side => 'left',
);;

my $dropDownLabel = $optionsFrame->Label(
	-text => 'email language',
)->pack(
    -side => 'left',
);

my $filesCheckBox = $optionsFrame->Checkbutton(
	-text => 'write files',
	-variable => \$config{"settings.writefiles"},
	-anchor => 'w',
    -command => sub{ 
        $result_status = 0;
        set_email_button(0);
        $consoleText->delete("1.0", 'end');
        print_options();
    },
)->pack(
    -side => 'left',
);;

my $optionsilentCheckBox = $optionsFrame->Checkbutton(
	-text => 'silent',
	-variable => \$config{"settings.silent"},
	-anchor => 'w',
    -command => sub{ 
        $result_status = 0;
        set_email_button(0);
        $consoleText->delete("1.0", 'end');
        print_options();
    },
)->pack(
    -side => 'left',
);;

my $quitButton = $mainWindow->Button(
    -text => 'Quit',
    -command => sub{ exit(); },
)->pack(
    -side => 'left',
);

my $emailButton = $mainWindow->Button(
    -text => 'Compose emails',
    -state => 'disabled',
    -command => sub{ send_mails(\@result) if $config{"settings.writefiles"} ; },
)->pack(
    -side => 'right',
);

tie *STDOUT, ref $consoleText, $consoleText;

$peopleListBox->insert('end', @allPeople);

for (0 .. scalar @allPeople -1) {
  if ( $allPeople[$_] ~~ @selectPeople ) {
    $peopleListBox->selectionSet($_);
  }
}

print "Welcome to Secret-Santa-O-Matic ".$version."\n\n";
print_options();
$mainWindow->MainLoop();


sub clean_results_directory {
    unlink glob("$option_resultspath/*")
}


sub send_mails { 
    my @recipients =  @{$_[0]}; # @recipients passed by reference
    if (scalar(@recipients)) {
        foreach (@recipients) {
            my @args = ("thunderbird", "-compose", "subject=\'".$config{"email.subject_".$config{"email.activelang"}}."\',to=\'".$_."\',body=\'".($config{"email.salutation_".$config{"email.activelang"}}." ".$_.",\n\n".$config{"email.body_".$config{"email.activelang"}} =~ s/\\n/\n/gr)."\n\',attachment=\'".$option_resultspath.$_.".txt\'");
            system(@args) == 0 or die "system @args failed: $?";
        }
    } else {
        print "\nResult set is empty! Try drawing lots first.\n";
    }
}


sub print_email_option {
    print "\nEmail language is '".$config{"email.activelang"}."'.\n";
}


sub print_options {
    print "Option 'silent' set to ".$config{"settings.silent"}.". ", $config{"settings.silent"} ? ("Supressing console output.\n") : ("Enabling console output.\n");
    print "Option 'writefiles' set to ".$config{"settings.writefiles"}.". ", $config{"settings.writefiles"} ? ("Enabling file output.\n") : ("Not writing to files.\n");
    print_email_option();
    print "If you want to compose emails, ", ($config{"settings.writefiles"}) ? ("draw lots") : ("enable option 'writefiles' and draw lots"), ".\n" unless ($config{"settings.writefiles"} and $result_status); 
    print "\nOutput path for files is '".$option_resultspath."'.\n" if $config{"settings.writefiles"};
}


sub set_email_button {
    my $set_state = $_[0]; 
    if ($set_state) {
      $emailButton->configure(-state => 'normal');
    } else {
      $emailButton->configure(-state => 'disabled');
    }
}


sub invert_selection {
  my @currentSelection = $peopleListBox->curselection; 
  for (0 .. scalar @allPeople -1) {
    if ($peopleListBox->selectionIncludes($_)) { 
      $peopleListBox->selectionClear($_);
    } else { 
      $peopleListBox->selectionSet($_);
    }
  }
}


sub generate_sequence {
    my @selection = @{$_[0]}; # @selection passed by reference
    my @sequence;
    if(scalar(@selection) < 2) {
      print "Please select at least two people!\n";
      return (\@sequence, 0);
    }

    my $validorder = 0;
    my $loopcounter = 0;

    # Try to generate sequence until a valid one has been found
    until($validorder or $loopcounter > 20) {
        (my $sequence_arr_ref, $validorder) = draw_lots(\@selection);
        @sequence = @$sequence_arr_ref;
        $loopcounter++;
    }

    if($config{"settings.writefiles"} and $validorder) {
        for my $i (0 .. $#sequence) {
            my $gifter = $sequence[$i];
            my $recipient = ($i == $#sequence) ? $sequence[0] : $sequence[$i+1];
            my $fullpath = $option_resultspath.$gifter.".txt";
            open my $out, '>', $fullpath or die "Error: cannot open file.";
            print $out "Hello ".$gifter."!\n\n";
            print $out "This text file has been automatically generated by 'Secret-Santa-O-Matic ".$version."'\n\n";
            print $out "You are secret santa for ... (drumroll) ...\n\n";
            print $out "     ".$recipient."\n\n";
            print $out "Enjoy! And please don't tell anyone!\n";
            print $out "\n                                          _";
            print $out "\n                                       .-(_)";
            print $out "\n                                      / _/";
            print $out "\n                                   .-'   \\";
            print $out "\n                                  /       '.";
            print $out "\n                                ,-~--~-~-~-~-,";
            print $out "\n                               {__.._...__..._}             ,888,";
            print $out "\n               ,888,          /\\##\"  6  6  \"##/\\          ,88' `88,";
            print $out "\n             ,88' '88,__     |(\\`    (__)    `/)|     __,88'     `88";
            print $out "\n            ,88'   .8(_ \\_____\\_    '----'    _/_____/ _)8.       8'";
            print $out "\n            88    (___)\\ \\      '-.__    __.-'      / /(___)";
            print $out "\n            88    (___)88 |          '--'          | 88(___)";
            print $out "\n            8'      (__)88,___/                \\___,88(__)";
            print $out "\n                      __`88,_/__________________\\_,88`__";
            print $out "\n                     /    `88,       |88|       ,88'    \\";
            print $out "\n                    /        `88,    |88|    ,88'        \\";
            print $out "\n                   /____________`88,_\\88/_,88`____________\\";
            print $out "\n                  /88888888888888888;8888;88888888888888888\\";
            print $out "\n                 /^^^^^^^^^^^^^^^^^^`/88\\^^^^^^^^^^^^^^^^^^\\";
            print $out "\n           jgs  /                    |88| \\============,     \\";
            print $out "\n               /_  __  __  __   _ __ |88|_|^  MERRY    | _ ___\\";
            print $out "\n               |;:.                  |88| | CHRISTMAS! |      |";
            print $out "\n               |;;:.                 |88| '============'      |";
            print $out "\n               |;;:.                 |88|                     |";
            print $out "\n               |::.                  |88|                     |";
            print $out "\n               |;;:'                 |88|                     |";
            print $out "\n               |:;,                  |88|                     |";
            print $out "\n               '---------------------\"\"\"\"---------------------'\n";
            close $out;
        } 
        print (scalar(@sequence));
        print " files written. ";
    }
    if($loopcounter > 20) {
      print "No valid sequence could be found in 20 runs. Please check selection and constraints. Done.\n";
      return (\@sequence, 0);
    }

    print "Done.\n";
    return (\@sequence, 1);
}


sub draw_lots {
    my $valid = 0;
    my @selection = @{$_[0]}; # @selection passed by reference
    my @peoplecopy = ();
    foreach (@selection) {
      push(@peoplecopy,$allPeople[$_]);
    }
    my $firstname = pop(@peoplecopy);
    my $currentname = $firstname;
    my @pairs;
    
    while(@peoplecopy) {
        print 'Choosing gift recipient for: '.$currentname."\n" unless $config{"settings.silent"};
        $valid = 0;
        my $retrycounter = 0;
        until($valid) {
            my $randomname = "";
            $randomname = $peoplecopy[rand @peoplecopy];
            print '  candidate: '.$randomname unless $config{"settings.silent"};
            # check if candidate is in list of illegal matches for current person
            if ($config{"illegal.".$currentname} and (index($config{"illegal.".$currentname},$randomname) != -1)) {
              print " ...invalid match!\n" unless $config{"settings.silent"};
              unless ($retrycounter++ < 20) { 
                print "Too many tries, aborting...\n\n" unless $config{"settings.silent"}; 
                return (\@pairs, 0); 
              }
            } else {
                print " ...accepted\n" unless $config{"settings.silent"};
                $valid = 1;
                my $index = 0;
                $index++ until $peoplecopy[$index] eq $randomname;
                splice(@peoplecopy, $index, 1);
                push (@pairs, $randomname);
                $currentname = $randomname;
            }
        }
    }
    # check if last and first in list are a valid combination
    if ($config{"illegal.".$currentname} and (index($config{"illegal.".$currentname},$firstname) != -1)) {
        print "Last and first are invalid match, aborting...\n\n" unless $config{"settings.silent"}; 
        return (\@pairs, 0); 
    }
    push(@pairs, $firstname);
    return (\@pairs, $valid);
}
