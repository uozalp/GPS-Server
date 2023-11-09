/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Dumping database structure for GPS
DROP DATABASE IF EXISTS `GPS`;
CREATE DATABASE IF NOT EXISTS `GPS` /*!40100 DEFAULT CHARACTER SET latin1 */;
USE `GPS`;

-- Dumping structure for table GPS.Coordinates
DROP TABLE IF EXISTS `Coordinates`;
CREATE TABLE IF NOT EXISTS `Coordinates` (
  `uuid` binary(16) NOT NULL,
  `uuid_text` varchar(36) GENERATED ALWAYS AS (insert(insert(insert(insert(hex(`uuid`),9,0,'-'),14,0,'-'),19,0,'-'),24,0,'-')) VIRTUAL,
  `submitDatetime` datetime NOT NULL,
  `vehicleDatetime` datetime NOT NULL,
  `ihdr` varchar(3) DEFAULT NULL,
  `deviceId` varchar(15) NOT NULL,
  `protocol` varchar(100) DEFAULT NULL,
  `validity` varchar(1) NOT NULL,
  `latitude` decimal(10,5) NOT NULL,
  `longitude` decimal(10,5) NOT NULL,
  `distance` decimal(17,2) DEFAULT NULL,
  `vehicleSpeed` decimal(5,2) DEFAULT NULL,
  `calculatedSpeed` decimal(7,2) DEFAULT NULL,
  `direction` int(3) DEFAULT NULL,
  `mcc` char(3) DEFAULT NULL,
  `mnc` varchar(5) DEFAULT NULL,
  `lac` varchar(10) DEFAULT NULL,
  `cid` varchar(10) DEFAULT NULL,
  `performance` decimal(9,6) DEFAULT NULL,
  `hex` blob,
  PRIMARY KEY (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ENCRYPTION='Y';

-- Data exporting was unselected.

-- Dumping structure for table GPS.TCP_Sessions
DROP TABLE IF EXISTS `TCP_Sessions`;
CREATE TABLE IF NOT EXISTS `TCP_Sessions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `deviceId` char(15) DEFAULT NULL,
  `Thread` char(100) NOT NULL,
  `TCPSocket` char(45) NOT NULL,
  `IP` varchar(15) NOT NULL,
  `Connected` datetime NOT NULL,
  `Keepalive` datetime DEFAULT NULL,
  `Closed` datetime DEFAULT NULL,
  `Status` varchar(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10823 DEFAULT CHARSET=utf8 ENCRYPTION='Y';

-- Data exporting was unselected.

-- Dumping structure for table GPS.Vehicles
DROP TABLE IF EXISTS `Vehicles`;
CREATE TABLE IF NOT EXISTS `Vehicles` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `identifier` char(10) NOT NULL,
  `phonenumber` char(8) NOT NULL,
  `TenantId` int(5) NOT NULL,
  `licensePlate` varchar(10) NOT NULL,
  `markerColor` varchar(20) NOT NULL,
  `name` varchar(45) NOT NULL,
  `vehicleType` varchar(45) NOT NULL,
  `activated` tinyint(1) NOT NULL,
  `debug` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8 ENCRYPTION='Y';

-- Data exporting was unselected.

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
