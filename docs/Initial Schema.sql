DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- VECTOR 타입을 사용하기 위한 확장 모듈 (필요시 주석 해제)
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TYPE GENDER AS ENUM('MALE', 'FEMALE');
CREATE TYPE MEMBER_STATUS AS ENUM('ACTIVE', 'SUSPENDED', 'WITHDRAWN', 'EXPELLED');
CREATE TYPE MEMBER_ROLE AS ENUM('USER', 'ADMIN');
CREATE TABLE member (
    member_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_member PRIMARY KEY (member_id),
    email VARCHAR(255) NOT NULL, CONSTRAINT up_member_email UNIQUE (email),
    password VARCHAR(255),
    nickname VARCHAR(50) NOT NULL, CONSTRAINT uq_member_nickname UNIQUE (nickname),
    name VARCHAR(10) NOT NULL,
    gender GENDER NOT NULL,
    birth_date DATE NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    status MEMBER_STATUS NOT NULL DEFAULT 'ACTIVE',
    role MEMBER_ROLE NOT NULL DEFAULT 'USER',
    score DOUBLE PRECISION NOT NULL DEFAULT 50,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP,
	suspended_at TIMESTAMP,
    bank_name VARCHAR(100),
    account_holder VARCHAR(50),
    account_number VARCHAR(100),
	warning_count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE category (
    category_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_category PRIMARY KEY (category_id),
    name VARCHAR(100) NOT NULL, CONSTRAINT uq_category_name UNIQUE (name)
);

CREATE TYPE PRODUCT_CONDITION AS ENUM('GOOD', 'NORMAL', 'BAD');
CREATE TYPE PRODUCT_STATUS AS ENUM('DRAFT', 'ACTIVE', 'SOLD', 'HIDDEN');
CREATE TABLE product (
    product_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_product PRIMARY KEY (product_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_product_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    category_id BIGINT NOT NULL, CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES category (category_id),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    condition PRODUCT_CONDITION NOT NULL,
    model_name VARCHAR(200),
    release_year INTEGER,
    market_price BIGINT,
    thumbnail_url VARCHAR(500),
    status PRODUCT_STATUS NOT NULL DEFAULT 'DRAFT',
    embedding vector(768),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE TYPE PRODUCT_IMAGE_TYPE AS ENUM('LEFT', 'RIGHT', 'FRONT', 'BACK', 'TOP', 'BOTTOM');
CREATE TABLE product_image (
    product_image_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_product_image PRIMARY KEY (product_image_id),
    product_id BIGINT NOT NULL, CONSTRAINT fk_product_image_product FOREIGN KEY (product_id) REFERENCES product (product_id),
    image_url VARCHAR(500) NOT NULL,
    type PRODUCT_IMAGE_TYPE NOT NULL
);

CREATE TABLE address (
    address_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_address PRIMARY KEY (address_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_address_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    number VARCHAR(50),
    address VARCHAR(500),
    name VARCHAR(100) NOT NULL,
    api_address_id VARCHAR(500) NOT NULL
);

CREATE TYPE AUCTION_TYPE AS ENUM('ENGLISH', 'DUTCH', 'SEALED');
CREATE TYPE AUCTION_STATUS AS ENUM('SCHEDULED', 'ACTIVE', 'ENDED', 'SOLD', 'FAILED', 'CANCELLED');
CREATE TABLE auction (
    auction_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_auction PRIMARY KEY (auction_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_auction_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    product_id BIGINT NOT NULL, CONSTRAINT fk_auction_product FOREIGN KEY (product_id) REFERENCES product (product_id),
    category_id BIGINT NOT NULL, CONSTRAINT fk_auction_category FOREIGN KEY (category_id) REFERENCES category (category_id),
    auction_type AUCTION_TYPE NOT NULL,
    start_price BIGINT NOT NULL,
    current_price BIGINT NOT NULL,
    bid_unit BIGINT NOT NULL,
    bid_unit_policy VARCHAR(20) NOT NULL,
    reserve_price BIGINT,
    start_at TIMESTAMP NOT NULL,
    original_end_at TIMESTAMP NOT NULL,
    end_at TIMESTAMP,
    status VARCHAR(20) NOT NULL,
    bid_count INTEGER NOT NULL DEFAULT 0,
    bidder_count INTEGER NOT NULL DEFAULT 0,
    view_count INTEGER NOT NULL DEFAULT 0,
    bookmark_count INTEGER NOT NULL DEFAULT 0,
    top_bid_id BIGINT,
    top_bidder_id BIGINT,
    extension_count INTEGER NOT NULL DEFAULT 0,
    deposit_amount BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE TABLE bid (
    bid_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_bid PRIMARY KEY (bid_id),
    auction_id BIGINT NOT NULL, CONSTRAINT fk_bid_auction FOREIGN KEY (auction_id) REFERENCES auction (auction_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_bid_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    amount BIGINT NOT NULL, CONSTRAINT uq_bid_auction_amount UNIQUE (auction_id, amount),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE auction
ADD CONSTRAINT fk_auction_top_bid FOREIGN KEY (top_bid_id) REFERENCES bid (bid_id),
ADD CONSTRAINT fk_auction_top_bidder FOREIGN KEY (top_bidder_id) REFERENCES member (member_id);

CREATE TABLE bookmark (
	bookmark_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_bookmark PRIMARY KEY (bookmark_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_bookmark_member FOREIGN KEY (member_id) REFERENCES member (member_id),
	auction_id BIGINT NOT NULL, CONSTRAINT fk_bookmark_auction FOREIGN KEY (auction_id) REFERENCES auction (auction_id)
);

CREATE TYPE BID_DEPOSIT_STATUS AS ENUM('HELD', 'RELEASED', 'FORFEITED', 'REFUNDED');
CREATE TABLE bid_deposit (
    bid_deposit_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_bid_deposit PRIMARY KEY (bid_deposit_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_bid_deposit_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    auction_id BIGINT NOT NULL, CONSTRAINT fk_bid_deposit_auction FOREIGN KEY (auction_id) REFERENCES auction (auction_id),
    amount BIGINT NOT NULL,
    status BID_DEPOSIT_STATUS NOT NULL,
    released_at TIMESTAMP
);

CREATE TYPE ORDER_STATUS AS ENUM('PENDING', 'PAID', 'PREPARING', 'SHIPPED', 'DELIEVERED', 'CONFIRMED', 'CANCELLED', 'REFUNDED');
CREATE TABLE "order" (
    order_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_order PRIMARY KEY (order_id),
    auction_id BIGINT NOT NULL, CONSTRAINT fk_order_auction FOREIGN KEY (auction_id) REFERENCES auction (auction_id),
    seller_id BIGINT NOT NULL, CONSTRAINT fk_order_seller FOREIGN KEY (seller_id) REFERENCES member (member_id),
    buyer_id BIGINT NOT NULL, CONSTRAINT fk_order_buyer FOREIGN KEY (buyer_id) REFERENCES member (member_id),
    final_price BIGINT NOT NULL,
    status ORDER_STATUS NOT NULL,
    payment_due TIMESTAMP NOT NULL,
    address JSONB,
    tracking_number VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    chatting_session_id VARCHAR(100) NOT NULL
);

CREATE TABLE payment (
	payment_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_payment PRIMARY KEY (payment_id),
	order_id BIGINT NOT NULL, CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES "order" (order_id),
	buyer_id BIGINT NOT NULL, CONSTRAINT fk_payment_buyer FOREIGN KEY (buyer_id) REFERENCES member (member_id),
	amount BIGINT NOT NULL,
	type VARCHAR(255) 	NOT NULL,
	refund_key VARCHAR(500)		NULL,
	receipt_url VARCHAR(500)		NULL,
	paid_at TIMESTAMP	DEFAULT CURRENT_TIMESTAMP	NOT NULL
);

CREATE TABLE settlement (
	settlement_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_settlement PRIMARY KEY (settlement_id),
	order_id BIGINT NOT NULL, CONSTRAINT fk_settlement_order FOREIGN KEY (order_id) REFERENCES "order" (order_id),
	seller_id BIGINT NOT NULL, CONSTRAINT fk_settlement_seller FOREIGN KEY (seller_id) REFERENCES member (member_id),
	gross_amount BIGINT NOT NULL,
	commision_fee BIGINT NOT NULL,
	net_amount BIGINT NOT NULL,
	bank_name VARCHAR(100) NOT NULL,
	account_number VARCHAR(500) NOT NULL,
	payout_at TIMESTAMP NOT NULL
);


CREATE TABLE chatting (
    chatting_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_chatting PRIMARY KEY (chatting_id),
    order_id BIGINT NOT NULL, CONSTRAINT fk_chatting_order FOREIGN KEY (order_id) REFERENCES "order" (order_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_chatting_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    content TEXT NOT NULL,
    time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE question (
    question_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_question PRIMARY KEY (question_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_question_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    answer TEXT,
    answered_at TIMESTAMP
);

CREATE TYPE REPORT_TYPE AS ENUM('AUCTION', 'ORDER', 'CHATTING');
CREATE TYPE REPORT_STATUS AS ENUM('PENDING', 'ACCEPTED', 'REFUNDED');
CREATE TABLE report (
    report_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_report PRIMARY KEY (report_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_report_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    content TEXT NOT NULL,
    type REPORT_TYPE NOT NULL,
    auction_id BIGINT, CONSTRAINT fk_report_auction FOREIGN KEY (auction_id) REFERENCES auction (auction_id),
    order_id BIGINT, CONSTRAINT fk_report_order FOREIGN KEY (order_id) REFERENCES "order" (order_id),
    status REPORT_STATUS NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP
);

CREATE TYPE MEMBER_EVENT_TYPE AS ENUM('VIEW', 'CLICK', 'WATCH', 'UNWATCH', 'BID', 'SHARE', 'SEARCH', 'PURCHASE', 'IMPRESSION', 'SCROLL_PASS');
CREATE TABLE member_event (
    member_event_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_member_event PRIMARY KEY (member_event_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_member_event_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    event_type MEMBER_EVENT_TYPE NOT NULL,
    metadata JSONB,
    occured_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    auction_id BIGINT NOT NULL, CONSTRAINT fk_member_event_auction FOREIGN KEY (auction_id) REFERENCES auction (auction_id),
    product_id BIGINT NOT NULL, CONSTRAINT fk_member_event_product FOREIGN KEY (product_id) REFERENCES product (product_id),
    category_id BIGINT NOT NULL, CONSTRAINT fk_member_event_category FOREIGN KEY (category_id) REFERENCES category (category_id)
);

CREATE TABLE fraud_label (
    fraud_label_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_fraud_label PRIMARY KEY (fraud_label_id),
    auction_id BIGINT NOT NULL, CONSTRAINT fk_fraud_label_auction FOREIGN KEY (auction_id) REFERENCES auction (auction_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_fraud_label_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    CONSTRAINT uq_fraud_label_auction_member UNIQUE (auction_id, member_id),
    label SMALLINT NOT NULL,
    label_source VARCHAR(30) NOT NULL,
    reason TEXT,
    confirmed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fraud_detection (
    detection_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY, CONSTRAINT pk_fraud_detection PRIMARY KEY (detection_id),
    auction_id BIGINT NOT NULL, CONSTRAINT fk_fraud_detection_auction FOREIGN KEY (auction_id) REFERENCES auction (auction_id),
    member_id BIGINT NOT NULL, CONSTRAINT fk_fraud_detection_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    bid_id BIGINT NOT NULL, CONSTRAINT fk_fraud_detection_bid FOREIGN KEY (bid_id) REFERENCES bid (bid_id),
    bidder_tendency DOUBLE PRECISION NOT NULL,
    bidding_ratio DOUBLE PRECISION NOT NULL,
    last_bidding DOUBLE PRECISION NOT NULL,
    auction_bids DOUBLE PRECISION NOT NULL,
    starting_price_average DOUBLE PRECISION NOT NULL,
    early_bidding DOUBLE PRECISION NOT NULL,
    winning_ratio DOUBLE PRECISION NOT NULL,
    auction_duration DOUBLE PRECISION NOT NULL,
    risk_score DOUBLE PRECISION NOT NULL,
    predicted_label SMALLINT NOT NULL,
    decision_threshold DOUBLE PRECISION NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    feature_version VARCHAR(50) NOT NULL,
    detected_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
