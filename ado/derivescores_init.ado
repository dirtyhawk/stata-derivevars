*! derivescores_init.ado: helper script for -derivescores- to initialize derivation tables
/*
	This procedure reads all tables delivered with -derivescores- into Stata,
	and saves them in the user's temporary directory;
	their relevant paths and other metadata are saved in global macros;
	this procedure is supposed to be executed before any other -derivescores-
	subcommand is called, and will automatically be executed if the called
	procedure detects that -derivescores init- has not been run in the Stata
	session before
*/
// TODO: mark crosswalks containig invalid declarations as invalid
program define derivescores_init , nclass
	// syntax declaration and macros
	syntax [, verbose ]
	local declarationfile `"conceptschemes_correspondences.csv"'
	local temppath `"`c(tmpdir)'/DERIVESCORES_tmp"'
	// check if derivescores_init has been run previously, abort if so (unless option -force- is set
	if (!missing(`"${DERIVESCORES_initialized}"')) {
		noisily : display as error in smcl `"{it:derivescores} already has been initialized;"' _newline `"{tab}continue with {stata derivescores info}, or clean up with {stata derivescores cleanup}"'
		exit 0
	}
	// find main CSV file with table declarations
	capture : findfile `"`declarationfile'"'
	if (_rc!=0) {
		noisily: display as error in smcl `"could not find table declaration file;"' _newline `"{tab}maybe your package installation is broken?"'
		exit 601
	}
	else local declarationfile `"`r(fn)'"'
	// read main CSV file with table declarations; save all metadata as globals
	preserve
	if (`"`verbose'"'=="verbose") noisily : display as text in smcl `"reading table declarations from file {result}{it:`declarationfile'}{text}"'
	quietly : import delimited `"`declarationfile'"' , clear varnames(1) case(preserve) encoding("utf-8")
	local total `c(N)'
	local invalid 0
	forvalues num=1/`total' {
		local counter=`num'-`invalid'
		local searchfilename
		if (missing(`"`=Correspondence[`num']'"')) {
			global DERIVESCORES_dec`counter'shortname=ConceptScheme[`num']
			local searchfilename=lower(ConceptScheme[`num'])+`".csv"'
			global DERIVESCORES_dec`counter'type ConceptScheme
		}
		else {
			global DERIVESCORES_dec`counter'shortname=ConceptScheme[`num']+`" --> "'+Correspondence[`num']
			local searchfilename=lower(ConceptScheme[`num'])+`"--"'+lower(Correspondence[`num'])+`".csv"'
			global DERIVESCORES_dec`counter'type Correspondence
		}
		global DERIVESCORES_dec`counter'file=ustrregexrf(`"`searchfilename'"',`"\.csv$"',`".dta"',.)
		capture : findfile `"`searchfilename'"'
		if (_rc!=0) {
			noisily: display as error in smcl `"could not find table file for {result}{it:${DERIVESCORES_dec`counter'type}}{error} {result}{it:${DERIVESCORES_dec`num'shortname}}{error} ({result}{it:`searchfilename'}{error});"' _newline `"{tab}it will not be available, nor any crosswalks to or from it;"' _newline `"{tab}maybe your package installation is broken?"'
			global DERIVESCORES_dec`counter'shortname
			global DERIVESCORES_dec`counter'type
			local --total
			local ++invalid
		}
		global DERIVESCORES_dec`counter'pkgfile `"`r(fn)'"'
		global DERIVESCORES_dec`counter'label=prefLabel[`num']
		global DERIVESCORES_dec`counter'note=coreContentNote[`num']
		global DERIVESCORES_dec`counter'sourcelink=source_overview[`num']
		global DERIVESCORES_dec`counter'deeplink=source_direct[`num']
		
	}
	global DERIVESCORES_deccount `total'
	clear
	// open each table declaration file, check for consistency, save temporarily in the user's temp directory
	quietly : mkdir `"`temppath'"'
	forvalues counter=1/`total' {
		global DERIVESCORES_dec`counter'file `"`temppath'/${DERIVESCORES_dec`counter'file}"'
		import delimited using `"${DERIVESCORES_dec`counter'pkgfile}"' , varnames(1) case(preserve) encoding("utf-8")
		quietly : save `"${DERIVESCORES_dec`counter'file}"'
	}
	restore
	// save global marking everything as initialized
	global DERIVESCORES_initialized 1
	// success message
	noisily : display as result in smcl `"{text}successfully read {result}{it:${DERIVESCORES_deccount}}{text} table declarations"'
	// quit
	exit 0
end
// EOF