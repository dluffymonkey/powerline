#!/bin/sh
FAILED=0

if [ "$(echo '\e')" != '\e' ] ; then
	safe_echo() {
		echo -E "$@"
	}
else
	safe_echo() {
		echo "$@"
	}
fi

check_screen_log() {
	if test -e tests/test_shells/${1}.ok ; then
		diff -u tests/test_shells/${1}.ok tests/shell/screen.log
		return $?
	else
		cat tests/shell/screen.log
		return 1
	fi
}

run_test() {
	SH="$1"
	SESNAME="powerline-shell-test-$$"
	screen -L -c tests/test_shells/screenrc -d -m -S "$SESNAME" \
		env LANG=en_US.UTF-8 BINDFILE="$BINDFILE" "$@"
	screen -S "$SESNAME" -X readreg a tests/test_shells/input.$SH
	# Wait for screen to initialize
	sleep 0.3s
	screen -S "$SESNAME" -p 0 -X width 300 1
	screen -S "$SESNAME" -p 0 -X logfile tests/shell/screen.log
	screen -S "$SESNAME" -p 0 -X paste a
	# Wait for screen to exit (sending command to non-existing screen session 
	# fails; when launched instance exits corresponding session is deleted)
	while screen -S "$SESNAME" -X blankerprg "" > /dev/null ; do
		sleep 0.1s
	done
	./tests/test_shells/postproc.py tests/shell/screen.log
	if ! check_screen_log ${SH} ; then
		# Repeat the diff to make it better viewable in travis output
		check_screen_log ${SH} | cat -v
		echo "Failed ${SH}"
		return 1
	fi
	return 0
}

mkdir tests/shell
git init tests/shell/3rd
git --git-dir=tests/shell/3rd/.git checkout -b BRANCH

if ! run_test bash --norc --noprofile -i ; then
	FAILED=1
fi
rm tests/shell/screen.log

if ! run_test zsh -f -i ; then
	FAILED=1
fi
rm tests/shell/screen.log

export XDG_CONFIG_HOME=/dev/null
if ! run_test fish -i ; then
	FAILED=1
fi
rm tests/shell/screen.log

rm -r tests/shell
exit $FAILED
