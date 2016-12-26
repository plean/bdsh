#!/bin/sh

SUCCESS=0
FAILURE=1
PROGNAME="${0##*/}"
USAGE="${PROGNAME} [-k] [-f <db_file>] (put (<clef> | $<clef>) (<valeur> | $<clef>) | del (<clef> | $<clef>) [<valeur> | $<clef>] | select [<expr> | $<clef>] | flush)"
SYNTAX_ERROR="Syntax error : Usage : ${USAGE}"
NO_SUCH_KEY="No such key :"
NO_BASE_FOUND="No base found : file"
DISPLAYKEY=NO
FILENAME="sh.db"
SEPARATOR=" "

debug() {
    echo DISPLAYKEY = "${DISPLAYKEY}"
    echo FILENAME = "${FILENAME}"
    echo PARAM = "${PARAM}"
    echo KEY = "${KEY}"
    echo VALUE = "${VALUE}"
    echo EXPR = "${EXPR}"
}

syntax_error() {
    >&2 echo "$SYNTAX_ERROR"
    exit $FAILURE
}

no_such_key() {
    >&2 echo "$NO_SUCH_KEY" "$1"
    exit $FAILURE
}

no_base_found() {
    >&2 echo "$NO_BASE_FOUND" "$FILENAME"
    exit $FAILURE
}

get_line() {
    grep -n "^${1}${SEPARATOR}" -- "$FILENAME" | sed 's/:.*//'
}

get_value() {
    grep -q "^${1}${SEPARATOR}" -- "$FILENAME" || no_such_key "$1"
    line=$(get_line "$1")
    tmp_value=$(sed "${line}q;d" -- "$FILENAME" | sed "s/^${1}${SEPARATOR}//")
}

get_param() {
    if [ "${#1}" -gt 0 ] && [ $(echo "$1" | head -c 1) = "$" ]
    then
        get_value "${1#$}"
    	get_param "$tmp_value"
    else
        tmp_value="$1"
    fi
}

aff_value() {
    [ "$DISPLAYKEY" = YES ] && echo "$KEY=$VALUE" || echo "$VALUE"
}

db_() {
    syntax_error
}

db_put() {
    touch -- "$FILENAME"
    [ -f "$FILENAME" -a -r "$FILENAME" -a -w "$FILENAME" ] || no_base_found
    get_param "$KEY"
    KEY="$tmp_value"
    get_param "$VALUE"
    VALUE="$tmp_value"
    sed -i "/^${KEY}${SEPARATOR}/d" -- "$FILENAME"
    echo "${KEY}${SEPARATOR}${VALUE}" >> "$FILENAME"
}

db_del() {
    [ -e "$FILENAME" -a -f "$FILENAME" -a -r "$FILENAME" -a -w "$FILENAME" ] || no_base_found
    get_param "$KEY"
    KEY="$tmp_value"
    grep -q "^${KEY}${SEPARATOR}" -- "$FILENAME" || return
    if [ -n "${VALUE+x}" ]
    then
	get_param "$VALUE"
	VALUE="$tmp_value"
	get_param "\$$KEY"
	OLD_VALUE="$tmp_value"
	[ "$VALUE" = "$OLD_VALUE" ] && echo "${KEY}${SEPARATOR}" >> "$FILENAME" || echo "${KEY}${SEPARATOR}${OLD_VALUE}" >> "$FILENAME"
    fi
    line=$(grep -n "^${KEY}${SEPARATOR}" "$FILENAME" | head -n 1 | sed 's/:.*//')
    sed -i ${line}d -- "$FILENAME"
}

db_select() {
    [ -f "$FILENAME" -a -r "$FILENAME" ] || no_base_found
    get_param "$EXPR"
    EXPR="$tmp_value"
    line=$(sed "s/${SEPARATOR}.*$//" -- "$FILENAME" | grep -n -- "$EXPR" | sed 's/:.*//')
    for i in $line
    do
	KEY=$(sed "${i}q;d" -- "$FILENAME" | sed "s/${SEPARATOR}.*$//")
	get_param "\$$KEY"
	VALUE="$tmp_value"
	aff_value
    done
}

db_flush() {
    [ -f "$FILENAME" -a -w "$FILENAME" ] && echo -n > "$FILENAME" || no_base_found
}

while [ $# -gt 0 ]
do
    key="$1"
    
    case $key in
	-k)
	    DISPLAYKEY=YES
	    ;;
	-f)
	    FILENAME="$2"
	    shift
	    ;;
	put)
	    [ -n "${PARAM+x}" -o $# -le 2 ] && syntax_error
	    PARAM="${key}"
	    KEY="$2"
	    shift
	    VALUE="$2"
	    shift
	    ;;
        del)
	    [ -n "${PARAM+x}" -o $# -le 1 ] && syntax_error
	    PARAM="${key}"
	    KEY="$2"
	    shift
	    if [ -n "${2+x}" ]
	    then
		VALUE="$2"
		shift
	    fi
	    ;;
        'select')
	    [ -n "${PARAM+x}" ] && syntax_error
	    PARAM="${key}"
	    if [ -n "${2+x}" ]
	    then
		EXPR="$2"
		shift
	    fi
	    ;;
        flush)
	    [ -n "${PARAM+x}" ] && syntax_error
	    PARAM="${key}"
	    ;;
	*)
	    syntax_error
	    ;;
    esac
    shift
done

db_$PARAM
