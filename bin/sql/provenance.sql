CREATE TABLE IF NOT EXISTS provenance
(
    username       	VARCHAR(30) NOT NULL,
    project        	VARCHAR(40) NOT NULL,
    workflow       	VARCHAR(40) NOT NULL,
	workflownumber	INT(6) NOT NULL,
    sample         	VARCHAR(40) NOT NULL,

	stage			VARCHAR(40) NOT NULL,
	stagenumber		INT(6) NOT NULL,
	
    package         VARCHAR(40) NOT NULL,
    version         VARCHAR(40) NOT NULL,
	installdir		VARCHAR(255) NOT NULL,
	location		VARCHAR(255) NOT NULL,

	host			VARCHAR(40) NOT NULL,
	ipaddress		VARCHAR(40) NOT NULL,
	status			VARCHAR(40) NOT NULL,
	time			datetime,
	stdout			TEXT,
	stderr			TEXT,
 
    PRIMARY KEY  (username, project, workflow, workflownumber, sample, stage, stagenumber, status, time)
);
