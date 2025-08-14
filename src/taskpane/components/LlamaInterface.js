import React, { useState } from 'react';
import {
  Accordion,
  AccordionHeader,
  AccordionItem,
  AccordionPanel,
} from '@fluentui/react-components';

import {
  TextField,
  PrimaryButton,
  Spinner,
  SpinnerSize,
  MessageBar,
  MessageBarType,
  DefaultButton,
  Dropdown,
} from '@fluentui/react';
import ReactMarkdown from 'react-markdown';

const LlamaInterface = () => {
  // State tanımlamaları yukarıda kalacak

  const [prompt, setPrompt] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [includeWordContent, setIncludeWordContent] = useState(false);
  const [wordEmbeddings, setWordEmbeddings] = useState([]);
  const [selectedModel, setSelectedModel] = useState('google/gemma-3-12b');

  const modelOptions = [
    { key: 'google/gemma-3-12b', text: 'Gemma 3 12B' },
    { key: 'qwen/qwen3-4b-thinking-2507', text: 'Qwen 3 4B' },
  ];

  const [files, setFiles] = useState([]);
  const [isProcessingFile, setIsProcessingFile] = useState(false);
  const [processingStatus, setProcessingStatus] = useState('');
  const [embeddings, setEmbeddings] = useState([]);
  const [totalProgress, setTotalProgress] = useState({ current: 0, total: 0 });

  // Prompt'un embedding'ini oluşturmak için callEmbeddingsAPI'yi kullanıyoruz
  const getPromptEmbedding = async (promptText) => {
    return await callEmbeddingsAPI(promptText);
  };

  // Cosine Similarity (Kosinüs Benzerliği) hesaplayan fonksiyon
  const cosineSimilarity = (vecA, vecB) => {
    const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
    const magnitudeA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
    const magnitudeB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
    return dotProduct / (magnitudeA * magnitudeB);
  };

  // Metni embeddings'e dönüştüren fonksiyon
  const callEmbeddingsAPI = async (text) => {
    const API_URL = 'http://127.0.0.1:1234/v1/embeddings';
    try {
      const response = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          input: text,
          // Burası güncellendi
          model: 'text-embedding-nomic-embed-text-v1.5',
        }),
      });
      if (!response.ok) {
        throw new Error(`API hatası: ${response.statusText}`);
      }
      const data = await response.json();
      return data.data[0].embedding;
    } catch (err) {
      console.error('Embeddings API çağrısı sırasında hata oluştu:', err);
      setError('Embeddings sunucusuna bağlanılamadı. Sunucunun açık olduğundan ve model adının doğru olduğundan emin olun.');
      return null;
    }
  };

  const handleFileChange = (event) => {
    const selectedFiles = Array.from(event.target.files);
    const validFiles = selectedFiles.filter(file => 
      file.name.endsWith('.txt') || 
      file.type.startsWith('image/')
    );
    
    if (validFiles.length === 0) {
      setFiles([]);
      setError('Lütfen .txt veya resim dosyaları seçin.');
      return;
    }

    if (validFiles.length !== selectedFiles.length) {
      setError('Bazı dosyalar desteklenmeyen formatta. Sadece .txt ve resim dosyaları işlenecek.');
    } else {
      setError('');
    }

    setFiles(validFiles);
  };

  const processImage = async (file) => {
    try {
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = async (e) => {
          const base64Image = e.target.result.split(',')[1];
          resolve({
            type: 'image',
            content: base64Image,
            source: file.name
          });
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });
    } catch (err) {
      console.error('Resim işleme hatası:', err);
      throw err;
    }
  };

  const processFileAndCreateEmbeddings = async () => {
    if (files.length === 0) {
      setError('Lütfen önce en az bir dosya seçin.');
      return;
    }
    setIsProcessingFile(true);
    setProcessingStatus('');
    setError('');

    const newEmbeddings = [];
    let totalProcessedChunks = 0;
    let totalChunks = 0;

    try {
      // Önce tüm dosyaların toplam chunk sayısını hesapla
      for (const file of files) {
        if (file.name.endsWith('.txt')) {
          const fileContent = await file.text();
          const words = fileContent.split(/\s+/);
          const fileChunks = Math.ceil(words.length / 500);
          totalChunks += fileChunks;
        } else if (file.type.startsWith('image/')) {
          totalChunks += 1; // Her resim bir chunk olarak sayılır
        }
      }

      setTotalProgress({ current: 0, total: totalChunks });

      // Dosyaları sırayla işle
      for (let fileIndex = 0; fileIndex < files.length; fileIndex++) {
        const file = files[fileIndex];
        setProcessingStatus(`${file.name} işleniyor... (${fileIndex + 1}/${files.length} dosya)`);

        if (file.type.startsWith('image/')) {
          // Resim dosyasını işle
          const imageData = await processImage(file);
          newEmbeddings.push({
            type: 'image',
            content: imageData.content,
            source: file.name,
            text: `Bu bir resim dosyasıdır: ${file.name}`
          });
          totalProcessedChunks++;
        } else {
          // Text dosyasını işle
          const fileContent = await file.text();
          const words = fileContent.split(/\s+/);
          const chunkSize = 500;
          const fileChunks = Math.ceil(words.length / chunkSize);

          for (let i = 0; i < words.length; i += chunkSize) {
            const chunk = words.slice(i, i + chunkSize).join(' ');
            const embedding = await callEmbeddingsAPI(chunk);
            
            if (embedding) {
              newEmbeddings.push({ 
                type: 'text',
                vector: embedding, 
                text: chunk,
                source: file.name 
              });
            }
            totalProcessedChunks++;
            setTotalProgress({ 
              current: totalProcessedChunks, 
              total: totalChunks 
            });
          }
        }
      }

      setEmbeddings([...embeddings, ...newEmbeddings]);
      setProcessingStatus(`${files.length} dosya başarıyla işlendi. Toplam ${totalChunks} parça embeddings ve resim içeriği kaydedildi.`);
    } catch (err) {
      console.error('Dosya işleme sırasında hata oluştu:', err);
      setError('Dosya okuma veya işleme hatası.');
    } finally {
      setIsProcessingFile(false);
    }
  };
  
  // API çağrısı yapan fonksiyon (Sohbet için, şimdi RAG ile zenginleştirildi)
const callLlamaAPI = async (promptText, messages = null, onUpdate = () => {}) => {
    const API_URL = 'http://127.0.0.1:1234/v1/chat/completions';
    
    try {
        // Messages parametresi sağlanmamışsa default messages'ı kullan
        if (!messages) {
            messages = [
                { role: 'system', content: 'You are a helpful assistant.' },
                { role: 'user', content: promptText }
            ];
        }

        // Chat API'ye istek gönder
        const response = await fetch(API_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                model: selectedModel,
                messages: messages,
                temperature: 0.7,
                stream: true, // Streaming'i aktif et
            }),
        });
        
        if (!response.ok) {
            throw new Error(`API hatası: ${response.statusText}`);
        }

        // Stream yanıtı okuma
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let accumulatedResponse = '';

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            // Gelen chunk'ı decode et
            const chunk = decoder.decode(value);
            const lines = chunk.split('\n');

            // Her satırı işle
            for (const line of lines) {
                if (line.startsWith('data: ') && line !== 'data: [DONE]') {
                    try {
                        const data = JSON.parse(line.substring(6));
                        const content = data.choices[0]?.delta?.content || '';
                        if (content) {
                            accumulatedResponse += content;
                            onUpdate(accumulatedResponse); // UI güncelleme callback'i
                        }
                    } catch (e) {
                        console.error('JSON parse hatası:', e);
                    }
                }
            }
        }

        return accumulatedResponse;
    } catch (err) {
        console.error('API çağrısı sırasında hata oluştu:', err);
        setError('LM Studio sunucusuna bağlanılamadı veya bir hata oluştu.');
        return null;
    }
};

  const processWordContent = async () => {
    try {
      const content = await Word.run(async (context) => {
        const body = context.document.body;
        body.load("text");
        await context.sync();
        return body.text;
      });

      if (!content.trim()) {
        setError('Word dokümanı boş.');
        return;
      }

      // İçeriği chunk'lara böl
      const words = content.split(/\s+/);
      const chunkSize = 500;
      const chunks = [];
      
      for (let i = 0; i < words.length; i += chunkSize) {
        const chunk = words.slice(i, i + chunkSize).join(' ');
        const embedding = await callEmbeddingsAPI(chunk);
        
        if (embedding) {
          chunks.push({
            type: 'word-content',
            vector: embedding,
            text: chunk,
            source: 'Word Dokümanı'
          });
        }
      }

      setWordEmbeddings(chunks);
      setError('');
      return true;
    } catch (error) {
      console.error('Word içeriği işlenirken hata:', error);
      setError('Word içeriği işlenirken bir hata oluştu.');
      return false;
    }
  };

  const handleGenerate = async () => {
    setLoading(true);
    setResponse('');
    setError('');
    
    if (!prompt.trim()) {
      setError('Lütfen bir prompt girin.');
      setLoading(false);
      return;
    }

    let allEmbeddings = [...embeddings];
    
    if (includeWordContent) {
      if (wordEmbeddings.length === 0) {
        const processed = await processWordContent();
        if (!processed) {
          setLoading(false);
          return;
        }
      }
      allEmbeddings = [...embeddings, ...wordEmbeddings];
    }

    let messages = [];
    if (allEmbeddings.length > 0) {
      const promptEmbedding = await callEmbeddingsAPI(prompt);
      const imageEmbeddings = allEmbeddings.filter(emb => emb.type === 'image');
      const textEmbeddings = allEmbeddings.filter(emb => emb.type === 'text' || emb.type === 'word-content');

      if (promptEmbedding) {
        const similarities = textEmbeddings.map(emb => ({
          text: emb.text,
          source: emb.source,
          similarity: cosineSimilarity(promptEmbedding, emb.vector),
          type: emb.type
        }));

        similarities.sort((a, b) => b.similarity - a.similarity);
        const topChunks = similarities.slice(0, 3); // En benzer 3 parçayı al

        const learningMessages = [];
        for (const chunk of topChunks) {
          if (chunk.similarity > 0.6) {
            learningMessages.push(
              { role: 'system', content: `Şimdi sana bir metin parçası vereceğim. Bu metin ${chunk.source}'dan alınmıştır. Oku ve anla.` },
              { role: 'user', content: chunk.text },
              { role: 'assistant', content: 'Metni okudum ve anladım.' }
            );
          }
        }

        if (learningMessages.length > 0 || imageEmbeddings.length > 0) {
          const imageMessages = imageEmbeddings.map(img => ({
            role: 'user',
            content: [
              {
                type: 'image',
                image_url: {
                  url: `data:image/jpeg;base64,${img.content}`
                }
              },
              {
                type: 'text',
                text: `Bu resmi incele: ${img.source}`
              }
            ]
          }));

          messages = [
            ...imageMessages,
            ...learningMessages,
            { 
              role: 'system', 
              content: 'Verilen metin ve resimleri incele. Sana sorulan soruları cevaplarken bu bilgileri kullan. Eğer yanıt mevcut değilse, bunu belirt.' 
            },
            { role: 'user', content: prompt }
          ];
        }
      }
    }

    if (messages.length === 0) {
      messages = [
        { role: 'system', content: 'You are a helpful assistant.' },
        { role: 'user', content: prompt }
      ];
    }

    // Streaming response handler
    const handleStreamUpdate = (accumulatedText) => {
      setResponse(accumulatedText);
    };

    const apiResponse = await callLlamaAPI(prompt, messages, handleStreamUpdate);
    setLoading(false);
  };

  const insertTextIntoWord = async () => {
    if (!response) return;
    
    await Word.run(async (context) => {
      const range = context.document.getSelection();
      range.insertText(response, Word.InsertLocation.after);
      await context.sync();
    });
  };

  return (
    <div style={{ padding: 15 }}>
      <h3>Kullanmak istediğiniz modeli seçin:</h3>
      <div style={{ marginBottom: 15 }}>
        <Dropdown
          label="Model Seçin"
          selectedKey={selectedModel}
          onChange={(e, option) => setSelectedModel(option.key)}
          options={modelOptions}
          styles={{ dropdown: { width: 300 } }}
        />
      </div>
      {error && (
        <MessageBar messageBarType={MessageBarType.error}>
          {error}
        </MessageBar>
      )}
      <div style={{ marginBottom: 15 }}>
        <input type="file" onChange={handleFileChange} multiple />
        <PrimaryButton
          text="Dosyaları İşle ve Embeddings Oluştur"
          onClick={processFileAndCreateEmbeddings}
          disabled={files.length === 0 || isProcessingFile}
          style={{ marginTop: 10 }}
        />
        {isProcessingFile && (
          <div style={{ marginTop: 10 }}>
            <Spinner
              size={SpinnerSize.small}
              label={`${processingStatus} (${totalProgress.current}/${totalProgress.total} parça)`}
            />
          </div>
        )}
        {files.length > 0 && !isProcessingFile && (
          <MessageBar
            messageBarType={MessageBarType.info}
            style={{ marginTop: 10 }}
          >
            Seçili Dosyalar: {files.map(f => f.name).join(', ')}
          </MessageBar>
        )}
      </div>
      {embeddings.length > 0 && (
          <MessageBar messageBarType={MessageBarType.success} style={{ marginBottom: 15 }}>
            {embeddings.length} adet embeddings hazır. Artık sohbet edebilirsiniz.
          </MessageBar>
      )}
      <div style={{ marginBottom: 10 }}>
        <label style={{ display: 'flex', alignItems: 'center' }}>
          <input
            type="checkbox"
            checked={includeWordContent}
            onChange={async (e) => {
              setIncludeWordContent(e.target.checked);
              if (e.target.checked && wordEmbeddings.length === 0) {
                setLoading(true);
                await processWordContent();
                setLoading(false);
              }
            }}
            style={{ marginRight: 8 }}
          />
          Word dokümanının içeriğini context'e ekle
        </label>
        {wordEmbeddings.length > 0 && (
          <MessageBar
            messageBarType={MessageBarType.success}
            style={{ marginTop: 10 }}
          >
            Word dokümanı işlendi ve {wordEmbeddings.length} parçaya bölündü.
          </MessageBar>
        )}
      </div>
      <TextField
        label="Prompt"
        multiline
        rows={6}
        value={prompt}
        onChange={(e, newValue) => setPrompt(newValue || '')}
        placeholder="Lütfen sormak istediğiniz metni buraya yazın..."
        style={{ marginBottom: 15 }}
      />
      <PrimaryButton
        text="Yanıt Oluştur"
        onClick={handleGenerate}
        disabled={loading}
        style={{ marginBottom: 15 }}
      />
      {loading && (
        <Spinner
          size={SpinnerSize.large}
          label="Yanıt bekleniyor..."
          style={{ marginBottom: 15 }}
        />
      )}
      <div style={{ border: '1px solid #ccc', padding: 10, borderRadius: 4, marginTop: 15 }}>
        <strong>Yanıt:</strong>
        <div style={{ 
          marginTop: 10, 
          marginBottom: 10, 
          minHeight: '100px',
          maxHeight: '300px',
          overflowY: 'auto',
          '& .ms-Accordion': { marginTop: '10px' }
        }}>
          {loading && !response && (
            <Spinner
              size={SpinnerSize.small}
              label="Yanıt bekleniyor..."
            />
          )}
          {response && (
            <>
              {/* Ana yanıt */}
              <div style={{ marginBottom: '10px' }}>
                <ReactMarkdown>
                  {response.split('<think>').map(part => part.split('</think>').pop()).join('')}
                </ReactMarkdown>
              </div>
              
              {/* Düşünme süreci accordion */}
              {response.includes('<think>') && (
                <Accordion style={{ marginTop: '10px' }}>
                  <AccordionItem value="thinking">
                    <AccordionHeader>Düşünme Süreci</AccordionHeader>
                    <AccordionPanel>
                      <div style={{ padding: '10px' }}>
                        <ReactMarkdown>
                          {response
                            .split('<think>')
                            .slice(1) // İlk parçayı atla (think tag'inden önceki kısım)
                            .map(part => part.split('</think>')[0]) // Her parçanın </think>'e kadar olan kısmını al
                            .join('\n\n') // Parçaları birleştir
                          }
                        </ReactMarkdown>
                      </div>
                    </AccordionPanel>
                  </AccordionItem>
                </Accordion>
              )}
            </>
          )}
        </div>
        {response && (
          <DefaultButton 
            text="Word'e Ekle" 
            onClick={insertTextIntoWord}
            style={{ marginTop: 10 }}
          />
        )}
      </div>
    </div>
  );
};

export default LlamaInterface;