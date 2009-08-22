# API
#	Class, Methods, Parameters
#	NOTE:
#		- This could be used for basic access control restrictions
#
{

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
		Methods => {
			getBasicInfo => { params => 2 },
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

