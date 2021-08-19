use strict;
use Cwd;
use File::Basename;

my $ScriptVersion     = "0.1";
my $Developer         = "StSc";
my $WorkDir           = getcwd;
my $ScriptPath        = $0;
$ScriptPath =~ s/\//\\/g;
my $ScriptFolder      = dirname($ScriptPath);
my $ScriptFile        = basename($ScriptPath);
my ($CurrentFileName) = $ScriptFile =~ m/(.+)\.\w+$/;
my ($BaseFolder)      = $ScriptFolder =~ m/(.+)\\/;
our ($BaselineDir) = $ScriptFolder =~ m/(.*)\\work\\tools/;
my $CfgFile           = "$BaseFolder\\cfg\\$CurrentFileName.cfg";
my $HeaderText  = "$CurrentFileName.pl Version: $ScriptVersion Developer: $Developer\n";
print "$HeaderText";


# Directories
my $TopFolder = GetBuildFolder();
$TopFolder =~ s/\//\\/ig;
my $BuildFolder = "";
my $NoBreak = 0;
my $TargetBldDir = "";
my $BuildProcName = "";
my $ProjVersLabel = "";
foreach my $param (@ARGV) {
    my $lparam = lc($param);
    if    ($lparam eq "nobreak")         { $NoBreak = 1; }
    elsif ($lparam eq "-nobreak")        { $NoBreak = 1; }
    elsif ($param =~ m/^\-t(.+)/i)       { $TargetBldDir = $1; }
    elsif ($param =~ m/^\-p(.+)/i)       { $BuildProcName = $1; }
    elsif ($param =~ m/^\-l(.+)/i)       { $ProjVersLabel = $1; }
}
if ($ProjVersLabel =~ m/FS\_(.*)/) {
  $ProjVersLabel = $1;
}

# Read Config
our $T32Config;
ReadConfig($CfgFile, "\$T32Config");
if ($BuildProcName eq "") { $BuildProcName = $T32Config->{DefaultProcName}; }
if ($TargetBldDir eq "") { $TargetBldDir = $T32Config->{DefaultBldDir}; }
if ($TargetBldDir eq "") {
  $BuildFolder = $TopFolder;
} else {
  $BuildFolder = $TopFolder . "\\" . $TargetBldDir;
}

my $SwName = "trace32_zip";
if ($ProjVersLabel ne "") {
  $SwName = $ProjVersLabel;
} else {
  if ( defined($T32Config->{TdXml}) ) {
    my $tdXmlFile = $TopFolder . "\\" . $T32Config->{TdXml};
    if (-e $tdXmlFile) {
        my $tmp = open FILE, "<$tdXmlFile";
        if ($tmp) {
            undef $/;
            my $text = <FILE>;
            close FILE;
            if ($text =~ m/$T32Config->{TdXmlProjVersLabel}/m) {
              $SwName = $+{PROJ_VERS_LABEL};
                print "PROJ_VERS_LABEL: " . $+{PROJ_VERS_LABEL} . "\n";
            }
        }
    }
  } elsif ($TopFolder =~ m/.*\\(.*?)$/) {
      $SwName = $1;
  }
}

my $TmpFolder = "$ENV{TEMP}";

my $exitCode = CreateTrace32Package($T32Config);
if ($NoBreak == 0) { Pause() };
if ($exitCode == 0)
{
    exit (0);
} else {
    exit (1);
}

sub CreateTrace32Package ($) {
  my $t32Config = shift;
  my $exit_state = 0;
  
  my $logFolder = "$BuildFolder\\proc\\$BuildProcName\\log";
  my $outFolder = "$BuildFolder\\out\\trace32";
  my $trace32Zip;
  my $numElems;
  
  unless(-d $logFolder) {
    unless(CreateDir($logFolder)) {
       print "Can't create directory: " . $logFolder;
       return 1;
    }
  }
  unless(-d $outFolder) {
    unless(CreateDir($outFolder)) {
       print "Can't create directory: " . $outFolder;
       return 1;
    }
  }

  my $logFile = "$logFolder\\trace32_package.log";

  open (LOG,"> $logFile");
  
  my $zipPath = "";
  my $td5ZipPath = $ENV{"7-ZIP_PATH"};

  if (-f $td5ZipPath . "7z.exe")
  {
     $zipPath = $td5ZipPath . "7z.exe";
  }
  elsif (-f "C:\\LegacyApp\\7-zip\\18.05\\7z.exe")
  {
    $zipPath = "C:\\LegacyApp\\7-zip\\18.05\\7z.exe";
  }
  elsif (-f "a:\\7-zip\\18.05\\7z.exe")
  {
     $zipPath = "a:\\7-zip\\18.05\\7z.exe";
  }
  else
  {
      print "No zipping tool found!";
      print LOG "No zipping tool found!";
      close LOG;
      return 1;
  }  
  
  print "Target Build Dir:  $TargetBldDir\n";
  print "Build Proc Name:   $BuildProcName\n";
  print "Tmp Folder:        $TmpFolder\n";

  print "Project path:      $TopFolder\n";
  print "7-Zip path:        $zipPath\n";

  print LOG "Target Build Dir:  $TargetBldDir\n";
  print LOG "Build Proc Name:   $BuildProcName\n";
  print LOG "Project path:      $TopFolder\n";
  print LOG "7-Zip path:        $zipPath\n";
  close LOG;

  my $numZipFiles = @{$t32Config->{ZipFiles}};
  for (my $i = 0; $i < $numZipFiles; $i++)   
  { 
    my $TmpZipName = $SwName;
    if ( defined($t32Config->{ZipFiles}->[$i]->{ProjVersLabelRegex}) ) {
      eval "\$TmpZipName =~ $t32Config->{ZipFiles}->[$i]->{ProjVersLabelRegex}"; 
    }
    my $TmpZipFolder = ".\\" . $TmpZipName . "\\*";
    my $TmpZipPath =  $TmpFolder . "\\" . $TmpZipName;
    $t32Config->{ZipFiles}->[$i]->{TmpZipPath} = $TmpZipPath;
    print "--------------------------------\n";
    print "Tmp Zip Folder:    $TmpZipFolder\n";
    print "Tmp Zip Path:      $TmpZipPath\n";
    $trace32Zip = $outFolder . "\\" . $TmpZipName . ".7z";
    DeleteFolder("$TmpZipPath");
    unless(-d $TmpZipPath) { CreateDir($TmpZipPath); } 
    if ( defined($t32Config->{ZipFiles}->[$i]->{TmpZipFolderMove}) ) {
      $numElems = @{$t32Config->{ZipFiles}->[$i]->{TmpZipFolderMove}};
      for (my $z = 0; $z < $numElems; $z++)   
      { 
        foreach my $key(keys %{$t32Config->{ZipFiles}->[$i]->{TmpZipFolderMove}->[$z]}) {
          if ($key =~ /^[+-]?\d+$/ ) {
            my $srcMove = $t32Config->{ZipFiles}->[$key]->{TmpZipPath} . "\\" . $t32Config->{ZipFiles}->[$i]->{TmpZipFolderMove}->[$z]->{$key};
            my $dstMove = $t32Config->{ZipFiles}->[$i]->{TmpZipPath} . "\\" . $t32Config->{ZipFiles}->[$i]->{TmpZipFolderMove}->[$z]->{Dest};
            print "Move " . $srcMove . " -- > " . $dstMove . "\n";
            unless(-d $dstMove) { CreateDir($dstMove); } 
            $srcMove =~ s/\\/\//g;    
            $dstMove =~ s/\\/\//g;  
            my $cmd = "mv " . $srcMove . "/* " . $dstMove;
            print $cmd . "\n";
            $exit_state = system($cmd);
            if ($exit_state != 0)
            {
              print "Error moving folder up!!!\n";
              return 1;
            }
          }
        }
      }
    }
       
    if ( defined($t32Config->{ZipFiles}->[$i]->{MergeZips}) ) {
      $numElems = @{$t32Config->{ZipFiles}->[$i]->{MergeZips}};
      for (my $z = 0; $z < $numElems; $z++)   
      {       
        my $zip = $TopFolder . "\\" . $t32Config->{ZipFiles}->[$i]->{MergeZips}->[$z]->{Zip};
        (my $fbase,undef,undef) = fileparse($zip, '\..*');
        my $cmd = "$zipPath x $zip  -r -y -bso0 -bsp0 -o$TmpZipPath";
        if ( defined($t32Config->{ZipFiles}->[$i]->{MergeZips}->[$z]->{Arg}) ) {
          $cmd .= " " . $t32Config->{ZipFiles}->[$i]->{MergeZips}->[$z]->{Arg};
        }
        print $cmd . "\n";
        $exit_state = system $cmd . "";
        if ($exit_state != 0)
        {
          print "Error unzipping!!!\n";
          return 1;
        }
      }
    }
    
    $numElems = @{$t32Config->{ZipFiles}->[$i]->{FolderCopy}};
    for (my $z = 0; $z < $numElems; $z++)   
    {       
        my $src = $TopFolder . "\\" . $t32Config->{ZipFiles}->[$i]->{FolderCopy}->[$z]->{Src};
        my $dest = $TmpZipPath . "\\" . $t32Config->{ZipFiles}->[$i]->{FolderCopy}->[$z]->{Dest};
        unless(-d $dest) {
          CreateDir($dest);
        } 
        
        XcopyFiles($src, $dest, $logFile);
    }
   
    open (LOG,">> $logFile");

    print "\nZipping started...\n";
    print LOG "\nZipping started...\n";

    if (-f "$trace32Zip")
    {
      unlink "$trace32Zip";
      if (-f "$trace32Zip")
      {
        print "Error removing old zip file $trace32Zip!!!\n";
        print LOG "Error removing old zip file $trace32Zip!!!\n";
      }
    }

    close LOG;
    my $startTime = time();
    my $cmd = "";
    if ($t32Config->{ZipFiles}->[$i]->{ZipSwName} == "1") {
      $cmd = "$zipPath a -r -mmt=on -mx4 $trace32Zip $TmpZipPath";
    } else {
      $cmd = "cd /D $TmpFolder&&$zipPath a -r -mmt=on -mx4 $trace32Zip $TmpZipFolder";
    }
    
    print $cmd . "\n";
    $exit_state = system $cmd . "";
    my $duration = time() - $startTime;
    print "Zipping duration: " . $duration . "s\n";
       
    if ($exit_state != 0)
    {
      print "Error on zipping!!!\n";
      open (LOG,">> $logFile");
      print LOG "Error on zipping!!!\n";
      close LOG;
      return 1;
    }  
    
    open (LOG,">> $logFile");
    print "\n$trace32Zip created!\n";
    print LOG "\n$trace32Zip created!\n";
    close LOG;    
  }
  print "--------------------------------\n";
  for (my $i = 0; $i < $numZipFiles; $i++)   
  { 
    my $tmp = $t32Config->{ZipFiles}->[$i]->{TmpZipPath};
    print "Remove $tmp ...\n";
    system "rd \/s \/q $tmp";
  }

  return 0;
}

sub CreateDir($) {
    my $cDir=$_[0];
    return 1 if -d $cDir;
    $cDir=~ /(.+?\\).+/;
    my $tDir=$1."\\";
    while ($cDir=~ /$tDir(.+?\\).+/) { #create parent dirs
        $tDir.=$1."\\";
        unless(-d $tDir) {
            unless(mkdir $tDir) {
                print("Can't create $tDir: $! !",0,"error");
                return 0;
            }
        }
    }
    unless(mkdir $cDir) {
        print("Can't create $cDir: $! !",0,"error");
        return 0;
    }
    return 1;
}


sub DeleteFolder($) {
    my $workdir = shift;    
    opendir (DIR, $workdir);
    my @dir = readdir (DIR);
    closedir(DIR);       
    
    foreach my $file (@dir) {
        next if ($file eq '.' or $file eq '..');
        my $dest = "$workdir\\$file";
        if (-d $dest) {
            DeleteFolder($dest);
            rmdir($dest) or warn "\nUnable to remove directory $dest: $!\n";
            next;
        }
        if ($dest ne "") {
            unlink($dest) or warn "\nUnable to delete file $dest:$!\n";
        }
    }
}

sub XcopyFiles($$$) {
  my $src = shift;
  my $dst = shift;
  my $logFile = shift;
  my $exit_state;
  
  print "Copy $src to $dst...\n";
  $exit_state = system "xcopy $src $dst /E /R /Y >> $logFile";
  if ($exit_state != 0)
  {
    print "Error on copying files!!!\n";
    return 0;
  }
  return 1;
}
        
# Read config
sub ReadConfig($$) {
    my $cfgFile = shift;
    my $config = shift;
    
    eval (
      'require "$cfgFile";'
    );
    
    if ($@ ne "") {
          print "Project configuration $cfgFile not found: $@!\n";
        if ($NoBreak == 0) { Pause() };
        exit(1);
    }

    if ( (!defined(eval($config))) ) {
          print "Project configuration not valid!\n";
        if ($NoBreak == 0) { Pause() };
        exit(1);        
    }
}


# Get top level build folder
sub GetBuildFolder() {
    my $buildFolder = $ScriptPath;
    $buildFolder =~ s/\//\\/g;
    if ($buildFolder =~ m/(.*)\\work\\tools/) {
        return $1;
    } elsif ($buildFolder =~ m/(.*)\\work\\$ScriptFile/) {
        return $1;
    }
}

sub GetFilePath($) {
    my $path = shift;
    my $dirname = dirname($path);
    my $pattern = basename($path);
    $pattern  =~ s(\.)(\\\.)gx;
    $pattern  =~ s(\?)(\.)gx;
    opendir (DIR, $dirname) or die "unable to open $dirname $!\n";
    my @files = grep{/$pattern$/i}readdir DIR;

    #print join("\n",@files),"\n";
    my $filePath = $dirname . "\\" . @files[0];
    if (@files[0] eq "") {
        print "File not found: " . $path . "\n";
        exit(1);    }

    #print $pattern . "-->" . $filePath . "\n";
    return $filePath;
}

sub Pause() {
    system("PAUSE");
}

