# API
#	Class, Methods, Parameters
#	NOTE:
#		- This could be used for basic access control restrictions
#
# NOTE on Convention
# 	Keys are currently case sensitive
# 	"Action" is as passed in from Ext Direct call
# 	"Method" is as passed in from Ext Direct call (and also must match Perl	method)
{

	# Default action / details
	# 	Support for overall before/after methods
	DEFAULT => {
		before => 'allowed',
		after => 'clean',
	},

	# LIST OF CLASSES BY NAME
	#	These are known as "Actions" in Direct
	#	Lookup, User, Profile ...
	
	Lookup => {
		# Real class to load for this class
		Class => 'Demo',
		# Access control - empty list equals any user
		ACL => { user => [] },
		# LIST OF METHODS
		Methods => {
			# params - number of paramaters, formHandler - must be form handler method (for uploads)
			suburb => { params => 1 },
		},
	},

	User => {
		Class => 'DemoObject',
		# Instantiate this classâ with new parameters below
		#	Note: It is done only once
		Instantiate => [],
		Methods => {
			list => { params => 0 },
			add => { params => 1 },
			delete => { params => 1 },
			update => { params => 1 },
		},
	},

	Profile => {
		Class => 'Demo',
		# Example of before/after methods - could be used for security and clean up
		#	string = method, string ref = Eval perl code, sub ref = sub
		before => 'allowed',
		after => 'clean',
		Methods => {
			getBasicInfo => { params => 2, before => 'getBasicInfo_test' },
			getPhoneInfo => { params => 1 },
			getLocationInfo => { params => 1 },
					# NOTE: Should be a JSON true - how?
			updateBasicInfo => { params => 2, formHandler => 1, },
			doTest => { params => 1 },
		},
	},

	TestAction => {
		Class => 'Demo',
		Methods => {
			doEcho => { params => 1, },
		},
	},

};

