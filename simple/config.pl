# API
#	Class, Methods, Parameters
#	NOTE:
#		- This could be used for basic access control restrictions
#
{
	Lookup => {
		suburb => { params => 1 },
	},

	User => {
		list => { params => 0 },
		add => { params => 1 },
		delete => { params => 1 },
		update => { params => 1 },
	},

	Profile => {
		getBasicInfo => { params => 2 },
		getPhoneInfo => { params => 1 },
		getLocationInfo => { params => 1 },
		updateBasicInfo => { params => 2, formHandler => 1, },
		doTest => { params => 1 },
	},

	TestAction => {
		doEcho => { params => 1, },
	},

};

