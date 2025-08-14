import * as React from "react";
import PropTypes from "prop-types";
import { Image, tokens, makeStyles } from "@fluentui/react-components";
import myLogo from '../../../assets/logo-alttayazi-tr-kirmizi.png';
const useStyles = makeStyles({
  welcome__header: {
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    paddingBottom: "2px",
    paddingTop: "2px",
    backgroundColor: tokens.colorNeutralBackground3,
    height: "110px",
  },
});

const Header = () => {
  const styles = useStyles();

  return (
    <section className={styles.welcome__header}>
      <Image width="100" height="100" src={myLogo} alt="PGD Logo" style={{ margin: '5px 0' }} />
    </section>
  );
};

// PropTypes are no longer needed as we don't use any props

export default Header;
