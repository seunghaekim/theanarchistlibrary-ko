-- Convert schema '/home/melmoth/amw/AmuseWikiFarm/dbicdh/_source/deploy/56/001-auto.yml' to '/home/melmoth/amw/AmuseWikiFarm/dbicdh/_source/deploy/57/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE custom_formats ADD COLUMN format_code varchar(8) NULL,
                           ADD UNIQUE site_id_format_code_unique (site_id, format_code);

;

COMMIT;

