# Template-Bare
Minimal Perl templating system

Template Bare is a stripped down/optimized version of Text::Template.
It was originally based off Text::Template version 1.46.

Nearly all features and options have been removed to target the specific use case of having templates with parantheses to indicate code blocks of perl.

The module supports the following two functions to fill in a template:
1. fill_in_string( $string, $perl_hash, $package_name );
  This function works similarly to the original fill_in_string function but takes arguments by position. The only way of passing in parameters is via a perl hash. A package name of the namespace to evaluate the template in must be provided.

2. tpl_to_chunks( $string, $perl_hash, $package );
  This function is just like fill_in_string but different in that instead of returning a flat string of the processed template it returns an array of the evaluated pieces. Additionally it supports an additional template substitution type of the format "template text {:text_param_1:text_param2:{$a}}". You can have as many text parameters as you want. $a in this example is whatever normal perl code you want. Note this format will not allow any colons within the perl code. That is a current limitation of how the code is processed.
