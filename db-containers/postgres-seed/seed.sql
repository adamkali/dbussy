-- Create the users table
CREATE TABLE users (
  id SERIAL PRIMARY KEY, -- Auto-incrementing integer for unique ID
  username VARCHAR(50) NOT NULL UNIQUE, -- Username for login
  email VARCHAR(100) NOT NULL UNIQUE, -- User's email address
  password_hash CHAR(60) NOT NULL -- Hashed password (store securely!)
);

-- Insert some sample users (replace with your desired passwords)
INSERT INTO users (username, email, password_hash)
VALUES ('john_doe', 'john.doe@example.com', 'abc123');
INSERT INTO users (username, email, password_hash)
VALUES ('jane_smith', 'jane.smith@example.com', 'abc123');

-- Note: Replace '...' with the actual hashed password using a secure hashing algorithm like bcrypt

