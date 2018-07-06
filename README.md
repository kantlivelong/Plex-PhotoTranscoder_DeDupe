## generate-test-files.sh

__USAGE__: generate-test-files.sh [--auto]
    creates a set of files in ./data
    by default creates 100 files of 100 random bytes with 10 duplicates of each file

- __OPTIONS__:
  - --auto : forces deletion of all previous test files (ie: skips the delete prompt)



## plex_phototranscoder_dedupe.sh

__USAGE__: dedup-new.sh /path/to/files
  - creates a list of all files on the supplied path with their timestamp and md5sum
  - retains the Original file
  - deletes each duplicate file
  - creates a symlink for the duplicate file name pointing to the original
 
 
