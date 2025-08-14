import * as React from 'react';
import {
  DefaultButton,
  Panel,
  Pivot,
  PivotItem,
  Stack,
  IStackTokens,
  initializeIcons,
} from '@fluentui/react';
import Header from './Header';
import LlamaInterface from './LlamaInterface'; // Yeni bileşenimizi import ediyoruz

// Fluent UI ikonlarını başlatın
initializeIcons();

const stackTokens = { childrenGap: 15 };

const App = () => {
  const [isOpen, setIsOpen] = React.useState(false);

  const togglePanel = () => {
    setIsOpen(!isOpen);
  };

  return (
    <Stack tokens={stackTokens}>
      <Header />
      <LlamaInterface /> {/* Kendi bileşenimizi buraya yerleştiriyoruz */}
    </Stack>
  );
};

export default App;