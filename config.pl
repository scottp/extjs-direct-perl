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

};

