# CMake integration for icecc/icecream
# Copyright (c) 2018 Stefan Bolus
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 
###############################################################################
# 
# The integration works best with icecream version 1.1 and higher. We have
# experienced some issues with 1.0.1 in the past when passing the actual
# compiler as first argument. In such cases, `icecc` was not able to call the 
# actual compiler.
# 
# The following variables are set by this script:
#  ICECC_FOUND
#  ICECC_VERSION
#  ICECC_EXECUTABLE
#  ICECC_CREATE_ENV_EXECUTABLE
# 
# The code defines a macro called `icecc_use()` to add `icecc` in front of each
# compiler call. The mechanism used to this is the global `RULE_LAUNCH_COMPILE`
# property.
# 
# If the C or C++ compiler are known at configuration time, then an additional
# target named `icecc-create-env` is created to create the toolchain
# environment for the current compiler. If any of the compilers is missing,
# the target will not be created. Both compilers are necessary to call the 
# auxiliary program `icecc-create-env`.
# 

find_program(ICECC_EXECUTABLE icecc
	HINTS /usr/local/bin /usr/bin 
	NO_CMAKE_FIND_ROOT_PATH
)

if(ICECC_EXECUTABLE)
	execute_process(COMMAND ${ICECC_EXECUTABLE} --version
		OUTPUT_VARIABLE _OUTPUT
		ERROR_QUIET
	)

	if(_OUTPUT MATCHES "^ICECC ([.0-9]+)")
		set(ICECC_VERSION ${CMAKE_MATCH_1})
	endif()

	unset(_OUTPUT)

	if(ICECC_EXECUTABLE)
		macro(icecc_use)
			message("Remark: Using icecc for the build. Do not forget to set `ICECC_VERSION` "
				"to the absolute path of the toolchain environment's .tar.gz file. "
				"The archive for the toolchain environment is created by `icecc-create-env --gcc <gcc-path> <g++-path>`. "
				"Set `ICECC_DEBUG=debug` for debugging purposes. To test remote builds "
				"set `ICECC_TEST_REMOTEBUILD=true` and `ICECC_PREFERRED_HOST` to your preferred node.")

			get_property(TMP_ GLOBAL PROPERTY RULE_LAUNCH_COMPILE)
			set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${TMP_} ${ICECC_EXECUTABLE}")
		endmacro()
	endif()


	find_program(ICECC_CREATE_ENV_EXECUTABLE icecc-create-env
		HINTS /usr/local/bin /usr/bin
		NO_CMAKE_FIND_ROOT_PATH
	)

	if(ICECC_CREATE_ENV_EXECUTABLE)
		# TODO Currently only GCC is supported.

		set(_C_COMPILER ${CMAKE_C_COMPILER})
		set(_CXX_COMPILER ${CMAKE_CXX_COMPILER})

		# The create-env script needs both, a C and a C++ compiler. If only 
		# one of them is used, then we pass the same compiler for both languages.
		if(NOT _C_COMPILER AND NOT _CXX_COMPILER)
			message(FATAL_ERROR "icecc used but neither a C or C++ compiler is present.")
		elseif(NOT _C_COMPILER)
			set(_C_COMPILER ${_CXX_COMPILER})
		elseif(NOT _CXX_COMPILER)
			set(_CXX_COMPILER ${_C_COMPILER})
		endif()

		set(_SCRIPT "\
TMPFILE=/tmp/cmake-icecc-\$\$.tmp\n \
RESULT=1\n \
echo \"Creating icecc toolchain environment for compilers ${_C_COMPILER} and ${_CXX_COMPILER}.\"\n \
\"${ICECC_CREATE_ENV_EXECUTABLE}\" --gcc \"${_C_COMPILER}\" \"${_CXX_COMPILER}\" | tee \"$TMPFILE\"\n \
if [ \${PIPESTATUS[0]} -ne 0 ]\; then\n \
	echo 'Generating icecc toolchain environment failed!'\n \
else\n \
	ENV_FILE=`cat \$TMPFILE | grep creating | awk '{print \$2}'`\n \
	echo \"Successfully created icecc environment. Set ICECC_VERSION=\"`pwd`\"/\$ENV_FILE to use it.\"\n \
	RESULT=0\n \
fi\n \
rm -f \"\$TMPFILE\"\n \
exit \$RESULT")
		file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/test.sh ${_SCRIPT})
		add_custom_target(icecc-create-env
			COMMAND sh ${CMAKE_CURRENT_BINARY_DIR}/test.sh
			COMMENT "Creating toolchain environment for icecc."
			WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
			VERBATIM
		)
	endif(ICECC_CREATE_ENV_EXECUTABLE)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ICECC
	REQUIRED_VARS ICECC_EXECUTABLE ICECC_CREATE_ENV_EXECUTABLE
    VERSION_VAR ICECC_VERSION
)