#!/usr/bin/env perl

############################################################################################
# Secret-Santa-O-Matic                                                                     #
#                                                                                          #
# written 2015-2020 by Matthias Budde                                                      # 
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
#                                                                                          #
############################################################################################

use strict;
use warnings;
use Cwd;
use Tk;
use File::Path qw( make_path );

my $version = "v0.94";

# Options TODO: Use config file to save and retreive data
my $option_resultspath = cwd()."/secret_santas/";
my $option_silent = 0;
my $option_writefiles = 1;
my $option_maxlistheight = 16;
my $option_emailto = "Dear";
my $option_emailsubject = "Mail from Secret-Santa-O-Matic!";
my $option_emailbody = "The Secret-Santa-O-Matic has rolled the dice again this year and found a nice person who you are Secret Santa for. His or her name is in the attached file, so that even the Secret-Santa-O-Matic does not know who will get a gift from you. Make it a good one! Merry Christmas!!!\n\nHo. Ho. Ho.\n\n-Your Secret-Santa-O-Matic";

# Create output path if it does not exist
if ( !-d $option_resultspath ) {
    make_path $option_resultspath or die "Failed to create path: $option_resultspath";
}

# Set participants of secret santa here TODO: Load from and save to config file
my @allPeople = sort("Alice", "Bob", "Eve", "Zoe");
my @selectPeople = sort("Alice", "Bob", "Zoe");

# Set exceptions here
my @illegal = (["Alice", "Bob"]
             );
my $numillegals = scalar(@illegal);

my @result;

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
    -height => scalar(@allPeople) >= $option_maxlistheight ?  $option_maxlistheight : scalar(@allPeople) 
)->pack();

my $buttonFrame = $topLeftFrame->Frame()->pack();

my $invertButton = $buttonFrame->Button(
    -text => 'invert',
    -command => sub{ invert_selection(); },
)->pack(
    -side => 'left',
);

# TODO: Edit-Button
# my $editButton = $buttonFrame->Button(
#     -text => 'settings',
#     -command => sub{ print "not yet implemented...\n"; },
# )->pack();

my $topRightFrame = $topFrame->Frame()->pack(
    -side => 'right',
    -anchor => 'n',
);
my $consoleText = $topRightFrame->Text()->pack();
my $optionsFrame = $topRightFrame->Frame()->pack();


my $doButton = $optionsFrame->Button(
    -text => 'Draw lots',
    -command => sub{ 
        $consoleText->delete("1.0", 'end');
        my @selection = $peopleListBox->curselection();
        clean_results_directory();
        generate_sequence(\@selection);
    },
)->pack(
    -anchor => 'n',
    -side => 'bottom',

);my $opionsLabel = $optionsFrame->Label(
	-text => 'Options:',
)->pack(
    -side => 'left',
);

my $filesCheckBox = $optionsFrame->Checkbutton(
	-text => 'write files',
	-variable => \$option_writefiles,
	-anchor => 'w',
    -command => sub{ 
        $consoleText->delete("1.0", 'end');
        print_options();
        #print "Option 'writefiles' set to ".$option_writefiles.". ", $option_writefiles ? ("Enabling file output.\n") : ("Not writing to files.\n");; 
    },
)->pack(
    -side => 'left',
);;

my $option_silentCheckBox = $optionsFrame->Checkbutton(
	-text => 'silent',
	-variable => \$option_silent,
	-anchor => 'w',
    -command => sub{ 
        $consoleText->delete("1.0", 'end');
        print_options();
        #print "Option 'silent' set to ".$option_silent.". ", $option_silent ? ("Supressing console output.\n") : ("Enabling console output.\n");; 
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
    -command => sub{ send_mails(); },
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

# TODO: change to pass result as parameter
sub send_mails { 
    if (scalar(@result)) {
        shift @result; #remove last element TODO: refactor so that this is done directly after drawing?
        foreach (@result) {
            my @args = ("thunderbird", "-compose", "subject='$option_emailsubject',to='$_',body='$option_emailto $_,\n\n$option_emailbody',attachment='$option_resultspath$_.txt'");
            system(@args) == 0 or die "system @args failed: $?";
        }
    } else {
        print "\nResult set is empty! Try drawing lots first.\n";
    }
}


sub print_options {
    print "Option 'silent' set to ".$option_silent.". ", $option_silent ? ("Supressing console output.\n") : ("Enabling console output.\n");; 
    print "Option 'writefiles' set to ".$option_writefiles.". ", $option_writefiles ? ("Enabling file output.\n") : ("Not writing to files.\n");; 
    print "\nOutput path for files is '".$option_resultspath."'.\n" if $option_writefiles;

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

    my $validorder = 0;
    my $loopcounter = 0;

    # Try to generate sequence until a valid one has been found
    until($validorder or $loopcounter > 20) {
        (my $result_arr_ref, $validorder) = draw_lots(\@selection);
        @result = @$result_arr_ref;
        $loopcounter++;
    }

    if($option_writefiles and $validorder) {
        my $numresults = scalar(@result);
        for my $i (0 .. $#result) {
            unless ($i == ($numresults-1)) {
                my $person = $result[$i];
                my $fullpath = $option_resultspath.$person.".txt";
                open my $out, '>', $fullpath or die "Error: cannot open file.";
                print $out "Hello ".$person."!\n\n";
                print $out "This text file has been automatically generated by 'Secret-Santa-O-Matic ".$version."'\n\n";
                print $out "You are secret santa for ... (drumroll) ...\n\n";
                print $out "     ".$result[$i+1]."\n\n";
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
        } 
        print ($numresults-1);
        print " files written. ";
    }
    if($loopcounter > 20) {
      print "No valid sequence could be found in 20 runs. Please check constraints. ";
    }

    print "Done.\n";
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
    push (@pairs, $firstname);
    
    while(@peoplecopy) {
        print 'Choosing gift recipient for: '.$currentname."\n" unless $option_silent;
        $valid = 0;
        my $retrycounter = 0;
        until($valid) {
            my $randomname = "";
            $randomname = $peoplecopy[rand @peoplecopy];
            print '  candidate: '.$randomname unless $option_silent;
            my $counter = 0;
            for my $i (@illegal) {
                # TODO: reimplement using hashes
                if ((grep {$_ eq $randomname} @$i) and (grep {$_ eq $currentname} @$i)){
                  print " ...invalid match!\n" unless $option_silent;
                  unless ($retrycounter++ < 20) { 
                    print "Too many tries, aborting...\n\n"; 
                    return \@pairs, 0; 
                  }
                } else {
                  $counter++;    
                }
            }    
            if ($counter == $numillegals) {
                print " ...accepted\n" unless $option_silent;
                $valid = 1;
                my $index = 0;
                $index++ until $peoplecopy[$index] eq $randomname;
                splice(@peoplecopy, $index, 1);
                push (@pairs, $randomname);
                $currentname = $randomname;
            }
        }
    }
    for my $i (@illegal) {
        if ((grep {$_ eq $firstname} @$i) and (grep {$_ eq $currentname} @$i)) {
            print "Last and first are invalid match, aborting...\n\n"; 
            return \@pairs, 0; 
        } 
    }
    push(@pairs, $firstname);
    return (\@pairs, $valid);
}
